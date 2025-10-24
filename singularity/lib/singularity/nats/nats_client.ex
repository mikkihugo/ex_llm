defmodule Singularity.NATSClient do
  @moduledoc """
  Uppercase alias for `Singularity.NATS.Client`.

  Prefer calling `Singularity.NATS.Client` directly; this module exists
  for call sites that want to keep the acronym capitalized while
  delegating to the canonical implementation.
  """

  alias Singularity.NATS.Client

  defdelegate publish(subject, data, opts \\ []), to: Client
  defdelegate request(subject, data, opts \\ []), to: Client
  defdelegate subscribe(subject_pattern, opts \\ []), to: Client
  defdelegate unsubscribe(subscription_id), to: Client
  defdelegate connected?, to: Client
  defdelegate status, to: Client
  defdelegate start_link(opts), to: Client
  defdelegate request_with_sparc_completion(subject, payload, opts \\ []), to: Client
  defdelegate track_nats_message_flow(event_type, subject, payload), to: Client
  defdelegate track_sparc_workflow_impact(workflow_id, phase, impact_metrics), to: Client
end

defmodule Singularity.NatsClient do
  @moduledoc """
  Compatibility wrapper for `Singularity.NATS.Client`.

  This module will be removed after downstream call sites finish
  migrating to the uppercase namespace.
  """

  alias Singularity.NATS.Client

  @deprecated "Use Singularity.NATS.Client.publish/3 instead."
  defdelegate publish(subject, data, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.request/3 instead."
  defdelegate request(subject, data, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.subscribe/2 instead."
  defdelegate subscribe(subject_pattern, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.unsubscribe/1 instead."
  defdelegate unsubscribe(subscription_id), to: Client

  @deprecated "Use Singularity.NATS.Client.connected?/0 instead."
  defdelegate connected?, to: Client

  @deprecated "Use Singularity.NATS.Client.status/0 instead."
  defdelegate status, to: Client

  @deprecated "Use Singularity.NATS.Client.start_link/1 instead."
  defdelegate start_link(opts), to: Client

  @deprecated "Use Singularity.NATS.Client.request_with_sparc_completion/3 instead."
  defdelegate request_with_sparc_completion(subject, payload, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.track_nats_message_flow/3 instead."
  defdelegate track_nats_message_flow(event_type, subject, payload), to: Client

  @deprecated "Use Singularity.NATS.Client.track_sparc_workflow_impact/3 instead."
  defdelegate track_sparc_workflow_impact(workflow_id, phase, impact_metrics), to: Client
end

defmodule Singularity.Nats.Client do
  @moduledoc """
  Compatibility wrapper for `Singularity.NATS.Client`.

  Maintains the original dotted namespace for teams that have not yet
  migrated to the uppercase module.
  """

  alias Singularity.NATS.Client

  @deprecated "Use Singularity.NATS.Client.publish/3 instead."
  defdelegate publish(subject, data, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.request/3 instead."
  defdelegate request(subject, data, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.subscribe/2 instead."
  defdelegate subscribe(subject_pattern, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.unsubscribe/1 instead."
  defdelegate unsubscribe(subscription_id), to: Client

  @deprecated "Use Singularity.NATS.Client.connected?/0 instead."
  defdelegate connected?, to: Client

  @deprecated "Use Singularity.NATS.Client.status/0 instead."
  defdelegate status, to: Client

  @deprecated "Use Singularity.NATS.Client.start_link/1 instead."
  defdelegate start_link(opts), to: Client

  @deprecated "Use Singularity.NATS.Client.request_with_sparc_completion/3 instead."
  defdelegate request_with_sparc_completion(subject, payload, opts \\ []), to: Client

  @deprecated "Use Singularity.NATS.Client.track_nats_message_flow/3 instead."
  defdelegate track_nats_message_flow(event_type, subject, payload), to: Client

  @deprecated "Use Singularity.NATS.Client.track_sparc_workflow_impact/3 instead."
  defdelegate track_sparc_workflow_impact(workflow_id, phase, impact_metrics), to: Client
end
