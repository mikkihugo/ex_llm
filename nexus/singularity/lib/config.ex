defmodule Singularity.Config do
  @moduledoc """
  Global configuration module that delegates to specialized config modules.

  This module provides a unified interface for accessing various configuration
  settings across the system.
  """

  @doc """
  Get task complexity for a provider.

  Delegates to Singularity.LLM.Config.get_task_complexity/2.
  """
  @spec get_task_complexity(String.t() | atom(), map()) ::
          {:ok, :simple | :medium | :complex} | {:error, term()}
  def get_task_complexity(provider, context \\ %{}) do
    Singularity.LLM.Config.get_task_complexity(provider, context)
  end
end
