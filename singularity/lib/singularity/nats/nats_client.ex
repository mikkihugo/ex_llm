defmodule Singularity.NatsClient do
  @moduledoc """
  Compatibility wrapper for `Singularity.Nats.Client`.

  This module will be deprecated in a future release. Prefer calling
  `Singularity.Nats.Client` directly in new code.
  """

  alias Singularity.Nats.Client

  @deprecated "Use Singularity.Nats.Client.publish/3 instead."
  defdelegate publish(subject, data, opts \\ []), to: Client

  @deprecated "Use Singularity.Nats.Client.request/3 instead."
  defdelegate request(subject, data, opts \\ []), to: Client

  @deprecated "Use Singularity.Nats.Client.subscribe/2 instead."
  defdelegate subscribe(subject_pattern, opts \\ []), to: Client

  @deprecated "Use Singularity.Nats.Client.unsubscribe/1 instead."
  defdelegate unsubscribe(subscription_id), to: Client

  @deprecated "Use Singularity.Nats.Client.connected?/0 instead."
  defdelegate connected?, to: Client

  @deprecated "Use Singularity.Nats.Client.status/0 instead."
  defdelegate status, to: Client

  @deprecated "Use Singularity.Nats.Client.start_link/1 instead."
  defdelegate start_link(opts), to: Client

  @deprecated "Use Singularity.Nats.Client.request_with_sparc_completion/3 instead."
  defdelegate request_with_sparc_completion(subject, payload, opts \\ []), to: Client

  @deprecated "Use Singularity.Nats.Client.track_nats_message_flow/3 instead."
  defdelegate track_nats_message_flow(event_type, subject, payload), to: Client

  @deprecated "Use Singularity.Nats.Client.track_sparc_workflow_impact/3 instead."
  defdelegate track_sparc_workflow_impact(workflow_id, phase, impact_metrics), to: Client
end
