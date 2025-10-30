defmodule Singularity.Infrastructure.PgFlow.Workflow do
  @moduledoc """
  Ecto schema for a PgFlow workflow.
  """
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias Singularity.Infrastructure.PgFlow.Queue

  @subscriptions_table :quantum_flow_workflow_subscriptions

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "quantum_flow_workflows" do
    field :workflow_id, :string
    field :type, :string
    field :payload, :map
    field :status, :string, default: "pending"

    timestamps()
  end

  @doc false
  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [:workflow_id, :type, :payload, :status])
    |> validate_required([:workflow_id, :type])
    |> unique_constraint(:workflow_id)
  end

  @doc """
  Create a workflow record and return the generated workflow identifier.

  This is a convenience wrapper that accepts a workflow module implementing
  `workflow_definition/0` and a payload map. It persists the workflow metadata
  and emits lightweight `:queued` notifications to any in-process subscribers.
  """
  @spec create_workflow(module(), map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_workflow(workflow_module, payload, opts \\ [])
      when is_atom(workflow_module) and is_map(payload) do
    workflow_def = workflow_module.workflow_definition()
    workflow_name = workflow_def[:name] || Atom.to_string(workflow_module)
    workflow_id = Keyword.get(opts, :workflow_id, build_workflow_id(workflow_name))

    attrs = %{
      workflow_id: workflow_id,
      type: workflow_name,
      payload: %{
        "workflow_module" => Atom.to_string(workflow_module),
        "payload" => payload
      },
      status: "pending"
    }

    case Queue.create_workflow(attrs) do
      {:ok, record} ->
        dispatch(workflow_name, %{status: :queued, workflow_id: record.workflow_id, payload: payload})
        {:ok, record.workflow_id}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    exception ->
      Logger.error("Failed to create QuantumFlow workflow",
        workflow_module: workflow_module,
        error: Exception.message(exception)
      )

      {:error, exception}
  end

  @doc """
  Subscribe to workflow notifications for the provided workflow identifier.

  Returns `{:ok, subscription_id}` where `subscription_id` can be used with
  `unsubscribe/1`. Subscribers are invoked with a single map argument describing
  the workflow event (currently `:queued` until the workflow engine integrates).
  """
  @spec subscribe(String.t(), (map() -> any()), keyword()) :: {:ok, reference()} | {:error, term()}
  def subscribe(workflow_name, callback, opts \\ [])
      when is_binary(workflow_name) and is_function(callback, 1) do
    ensure_subscription_table()

    subscription_id =
      {:quantum_flow_subscription, workflow_name, System.unique_integer([:positive, :monotonic])}

    :ets.insert(@subscriptions_table, {subscription_id, workflow_name, callback})

    Logger.debug("Registered QuantumFlow workflow subscription",
      workflow: workflow_name,
      subscription_id: subscription_id,
      mode: Keyword.get(opts, :mode, :in_memory)
    )

    {:ok, subscription_id}
  rescue
    exception ->
      {:error, exception}
  end

  @doc """
  Unsubscribe from workflow notifications.
  """
  @spec unsubscribe(reference()) :: :ok
  def unsubscribe(subscription_id) do
    if :ets.whereis(@subscriptions_table) != :undefined do
      :ets.delete(@subscriptions_table, subscription_id)
    end

    :ok
  end

  @doc """
  Dispatch a workflow lifecycle event to local subscribers.

  This can be used by the workflow engine once a workflow reaches completion or
  hits an error. Events should be maps including `:status` and `:workflow_id`.
  """
  @spec dispatch(String.t(), map()) :: :ok
  def dispatch(workflow_name, event) when is_binary(workflow_name) and is_map(event) do
    ensure_subscription_table()

    case :ets.whereis(@subscriptions_table) do
      :undefined ->
        :ok

      _table ->
        event_with_name = Map.put_new(event, :workflow, workflow_name)

        @subscriptions_table
        |> :ets.match_object({:"$1", workflow_name, :"$2"})
        |> Enum.each(fn {_id, _name, callback} ->
          safe_invoke(callback, event_with_name)
        end)

        :ok
    end
  end

  defp ensure_subscription_table do
    case :ets.whereis(@subscriptions_table) do
      :undefined ->
        :ets.new(@subscriptions_table, [:named_table, :public, :set, {:read_concurrency, true}])

      _table ->
        :ok
    end
  end

  defp safe_invoke(callback, event) do
    callback.(event)
  rescue
    exception ->
      Logger.error("QuantumFlow workflow subscription callback failed",
        error: Exception.message(exception),
        event: event
      )

      :ok
  end

  defp build_workflow_id(workflow_name) do
    "#{workflow_name}-#{System.unique_integer([:positive, :monotonic])}"
  end
end
