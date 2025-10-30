defmodule Singularity.Infrastructure.PgFlow.Queue do
  @moduledoc """
  Main context for PgFlow operations with integrated real-time messaging.

  Combines workflow management with PGMQ + PostgreSQL NOTIFY for reliable,
  real-time message delivery across all system components.
  """

  require Logger
  alias Singularity.Infrastructure.PgFlow.Repo
  alias Singularity.Infrastructure.PgFlow.Workflow
  alias Pgflow

  defdelegate persist_workflow(attrs), to: __MODULE__, as: :create_workflow
  defdelegate fetch_workflow(id), to: __MODULE__, as: :get_workflow

  # -- Workflow Management --------------------------------------------------------

  def create_workflow(attrs) do
    %Workflow{}
    |> Workflow.changeset(attrs)
    |> Repo.insert()
  end

  def get_workflow(id) do
    Repo.get_by(Workflow, workflow_id: id)
  end

  def update_workflow_status(workflow, status) do
    workflow
    |> Workflow.changeset(%{status: status})
    |> Repo.update()
  end

  # -- Real-time Messaging via PGMQ + NOTIFY -------------------------------------

  @doc """
  Send a message via PGMQ with PostgreSQL NOTIFY for real-time delivery.

  ## Parameters
  - `queue_name` - PGMQ queue name
  - `message` - Message payload (will be JSON encoded)
  - `repo` - Ecto repository (defaults to Singularity.Repo)

  ## Returns
  - `{:ok, :sent}` or `{:ok, response}` - Message sent successfully
  - `{:error, reason}` - Send failed

  ## Example
      {:ok, :sent} = Singularity.Infrastructure.PgFlow.Queue.send_with_notify(
        "chat_messages", 
        %{type: "notification", content: "Hello!"}
      )
  """
  @spec send_with_notify(String.t(), map(), Ecto.Repo.t()) :: {:ok, term()} | {:error, any()}
  def send_with_notify(queue_name, message, repo \\ Singularity.Repo) do
    case Pgflow.send_with_notify(queue_name, message, repo, expect_reply: false) do
      :ok -> {:ok, :sent}
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send notification only (no PGMQ persistence) for lightweight real-time updates.

  ## Parameters
  - `channel` - PostgreSQL NOTIFY channel
  - `payload` - Notification payload
  - `repo` - Ecto repository (defaults to Singularity.Repo)

  ## Returns
  - `:ok` - Notification sent
  - `{:error, reason}` - Send failed

  ## Example
      :ok = Singularity.Infrastructure.PgFlow.Queue.notify_only("knowledge_requests", "request_updated")
  """
  @spec notify_only(String.t(), String.t(), Ecto.Repo.t()) :: :ok | {:error, any()}
  def notify_only(channel, payload, repo \\ Singularity.Repo) do
    Pgflow.notify_only(channel, payload, repo)
  end

  @doc """
  Listen for NOTIFY events on a PGMQ queue.

  ## Parameters
  - `queue_name` - PGMQ queue name to listen for
  - `repo` - Ecto repository (defaults to Singularity.Repo)

  ## Returns
  - `{:ok, pid}` - Notification listener process
  - `{:error, reason}` - Failed to start listener

  ## Example
      {:ok, pid} = PgFlow.listen("observer_notifications")
      
      # Listen for messages
      receive do
        {:notification, ^pid, "pgmq_observer_notifications", message_id} ->
          # Poll PGMQ for the actual message
          {:ok, message} = PgFlow.read_message("observer_notifications", message_id)
          # Process message...
      end
  """
  @spec listen(String.t(), Ecto.Repo.t()) :: {:ok, pid()} | {:error, any()}
  def listen(queue_name, repo \\ Singularity.Repo) do
    Pgflow.listen(queue_name, repo)
  end

  @doc """
  Read a message from PGMQ queue.

  ## Parameters
  - `queue_name` - PGMQ queue name
  - `message_id` - Message ID to read
  - `repo` - Ecto repository (defaults to Singularity.Repo)

  ## Returns
  - `{:ok, message}` - Message read successfully
  - `{:error, reason}` - Read failed
  """
  @spec read_message(String.t(), String.t(), Ecto.Repo.t()) :: {:ok, map()} | {:error, any()}
  def read_message(queue_name, message_id, repo \\ Singularity.Repo) do
    Database.MessageQueue.receive_message(queue_name)
  end

  @doc """
  Stop listening for notifications.

  ## Parameters
  - `pid` - Notification listener process
  - `repo` - Ecto repository (defaults to Singularity.Repo)

  ## Returns
  - `:ok` - Stopped successfully
  - `{:error, reason}` - Stop failed
  """
  @spec unlisten(pid(), Ecto.Repo.t()) :: :ok | {:error, any()}
  def unlisten(pid, repo \\ Singularity.Repo) do
    Pgflow.unlisten(pid, repo)
  end

  # -- Private Helpers ------------------------------------------------------------
end
