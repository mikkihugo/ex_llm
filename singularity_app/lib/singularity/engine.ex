defmodule Singularity.Engine do
  @moduledoc """
  Behaviour implemented by each runtime engine (architecture, code, prompt, etc.).

  Engines expose metadata that the prototype can enumerate to discover available
  capabilities without hard-coding per-engine knowledge.
  """

  @typedoc "Opaque identifier for the engine (eg. :architecture, :prompt)."
  @type id :: atom()

  @typedoc "High-level capability descriptor exposed by an engine."
  @type capability :: %{
          id: atom(),
          label: String.t(),
          description: String.t(),
          available?: boolean(),
          tags: [atom()]
        }

  @callback id() :: id()
  @callback label() :: String.t()
  @callback description() :: String.t()
  @callback capabilities() :: [capability()]
  @callback health() :: :ok | {:error, term()}

  @optional_callbacks health: 0
end
