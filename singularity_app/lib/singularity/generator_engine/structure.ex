defmodule Singularity.GeneratorEngine.Structure do
  @moduledoc false

  alias Singularity.GeneratorEngine.Util

  @spec suggest_microservice_structure(String.t(), String.t()) :: {:ok, map()}
  def suggest_microservice_structure(domain, language) do
    base = Util.slug(domain)

    {:ok,
     %{
       structure: %{
         modules: [String.capitalize(base), "#{String.capitalize(base)}Service"],
         files: ["lib/#{base}.#{Util.extension(language)}"],
         directories: ["lib", "test", "config"]
       }
     }}
  end

  @spec suggest_monorepo_structure(String.t(), String.t()) :: {:ok, map()}
  def suggest_monorepo_structure(build_system, project_type) do
    {:ok,
     %{
       structure: %{
         apps: ["#{project_type}_app", "#{project_type}_worker"],
         shared: ["shared/#{build_system}"],
         root_files: ["README.md", "#{build_system}.config"]
       }
     }}
  end
end
