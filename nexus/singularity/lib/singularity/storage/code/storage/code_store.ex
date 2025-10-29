defmodule Singularity.CodeStore do
  @moduledoc """
  Persists generated code artifacts to disk for hot reload and version history.
  Extended to support multiple codebases (singularity, singularity-engine, learning codebases).
  """
  use GenServer
  require Logger

  alias Singularity.Metrics.Pipeline, as: MetricsPipeline

  @type state :: %{
          root: String.t(),
          active: String.t(),
          versions: String.t(),
          queues: String.t(),
          codebases: %{String.t() => %{path: String.t(), type: atom(), metadata: map()}},
          active_codebase: String.t()
        }

  # Keep versions for 7 days
  @version_ttl_hours 24 * 7
  # Run cleanup every 6 hours
  @cleanup_interval_ms :timer.hours(6)

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def paths do
    GenServer.call(__MODULE__, :paths)
  end

  def stage(agent_id, version, code, metadata \\ %{}) when is_binary(code) do
    GenServer.call(__MODULE__, {:stage, agent_id, version, code, metadata})
  end

  def promote(agent_id, version_path) do
    GenServer.call(__MODULE__, {:promote, agent_id, version_path})
  end

  def load_queue(agent_id) when is_binary(agent_id) do
    GenServer.call(__MODULE__, {:load_queue, agent_id})
  end

  def save_queue(agent_id, entries) when is_binary(agent_id) and is_list(entries) do
    GenServer.cast(__MODULE__, {:save_queue, agent_id, entries})
  end

  def load_vision do
    GenServer.call(__MODULE__, :load_vision)
  end

  def save_vision(vision_data) do
    GenServer.cast(__MODULE__, {:save_vision, vision_data})
  end

  # Multi-codebase API
  def register_codebase(codebase_id, codebase_path, type \\ :learning, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register_codebase, codebase_id, codebase_path, type, metadata})
  end

  def list_codebases do
    GenServer.call(__MODULE__, :list_codebases)
  end

  def set_active_codebase(codebase_id) do
    GenServer.call(__MODULE__, {:set_active_codebase, codebase_id})
  end

  def get_active_codebase do
    GenServer.call(__MODULE__, :get_active_codebase)
  end

  def analyze_codebase(codebase_id) do
    GenServer.call(__MODULE__, {:analyze_codebase, codebase_id})
  end

  def compare_codebases(codebase_id_1, codebase_id_2) do
    GenServer.call(__MODULE__, {:compare_codebases, codebase_id_1, codebase_id_2})
  end

  def store_analysis(codebase_id, analysis_data) do
    GenServer.cast(__MODULE__, {:store_analysis, codebase_id, analysis_data})
  end

  def get_analysis(codebase_id) do
    GenServer.call(__MODULE__, {:get_analysis, codebase_id})
  end

  def generate_refactoring_plan do
    GenServer.call(__MODULE__, :generate_refactoring_plan)
  end

  def get_training_samples(opts \\ []) do
    language = Keyword.get(opts, :language, "elixir")
    min_length = Keyword.get(opts, :min_length, 50)
    limit = Keyword.get(opts, :limit, 1000)

    GenServer.call(__MODULE__, {:get_training_samples, language, min_length, limit})
  end

  ## Server callbacks

  @impl true
  def init(opts) do
    root = Path.expand(System.get_env("CODE_ROOT", "./code"))
    active = Path.join(root, "active")
    versions = Path.join(root, "versions")
    queues = Path.join(root, "queues")
    analyses = Path.join(root, "analyses")

    with :ok <- ensure_dir(active),
         :ok <- ensure_dir(versions),
         :ok <- ensure_dir(queues),
         :ok <- ensure_dir(analyses) do
      # Initialize with default codebases (auto-detect from git)
      codebases = %{
        "singularity" => %{
          path: detect_repo_root(),
          type: :singularity,
          metadata: %{description: "Current singularity codebase"}
        }
      }

      # Schedule first cleanup
      schedule_cleanup()

      {:ok,
       %{
         root: root,
         active: active,
         versions: versions,
         queues: queues,
         codebases: codebases,
         active_codebase: "singularity"
       }}
    else
      {:error, reason} ->
        {:stop, {:code_store_init_failed, reason}}
    end
  end

  @impl true
  def handle_call(:paths, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:stage, _agent_id, _version, _code, _metadata}, _from, state) do
    {:reply, {:error, :invalid_code}, state}
  end

  def handle_call({:stage, agent_id, version, code, metadata}, _from, state)
      when is_binary(code) and byte_size(code) > 0 do
    version_id =
      [agent_id, version, System.system_time(:millisecond)]
      |> Enum.join("-")

    version_file = Path.join(state.versions, "#{version_id}.exs")
    metadata_file = Path.rootname(version_file) <> ".json"

    with :ok <- File.write(version_file, code),
         {:ok, json} <- Jason.encode(Map.put(metadata, :version_id, version_id)),
         :ok <- File.write(metadata_file, json) do
      {:reply, {:ok, version_file}, state}
    else
      {:error, reason} ->
        # Cleanup partial write
        File.rm(version_file)
        File.rm(metadata_file)
        {:reply, {:error, {:stage_failed, reason}}, state}
    end
  end

  def handle_call({:promote, agent_id, version_path}, _from, state) do
    active_file = Path.join(state.active, "#{agent_id}.exs")

    case File.cp(version_path, active_file) do
      :ok ->
        {:reply, {:ok, active_file}, state}

      {:error, reason} ->
        {:reply, {:error, {:promote_failed, reason}}, state}
    end
  end

  def handle_call({:load_queue, agent_id}, _from, state) do
    queue_path = queue_path(state.queues, agent_id)

    queue =
      case File.read(queue_path) do
        {:ok, contents} ->
          case Jason.decode(contents) do
            {:ok, list} when is_list(list) ->
              list
              |> Enum.map(&map_to_queue_entry/1)
              |> Enum.reject(&is_nil/1)

            _ ->
              []
          end

        _ ->
          []
      end

    {:reply, queue, state}
  end

  @impl true
  def handle_call(:load_vision, _from, state) do
    vision_path = Path.join(state.root, "vision.json")

    vision =
      case File.read(vision_path) do
        {:ok, contents} ->
          case Jason.decode(contents) do
            {:ok, data} -> data
            _ -> nil
          end

        _ ->
          nil
      end

    {:reply, vision, state}
  end

  @impl true
  def handle_call({:register_codebase, codebase_id, codebase_path, type, metadata}, _from, state) do
    if File.exists?(codebase_path) do
      new_codebase = %{
        path: codebase_path,
        type: type,
        metadata: Map.put(metadata, :registered_at, DateTime.utc_now())
      }

      updated_codebases = Map.put(state.codebases, codebase_id, new_codebase)
      updated_state = %{state | codebases: updated_codebases}

      {:reply, {:ok, codebase_id}, updated_state}
    else
      {:reply, {:error, :path_not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_codebases, _from, state) do
    codebase_list =
      Enum.map(state.codebases, fn {id, data} ->
        %{
          id: id,
          path: data.path,
          type: data.type,
          metadata: data.metadata,
          exists: File.exists?(data.path)
        }
      end)

    {:reply, codebase_list, state}
  end

  @impl true
  def handle_call({:set_active_codebase, codebase_id}, _from, state) do
    if Map.has_key?(state.codebases, codebase_id) do
      updated_state = %{state | active_codebase: codebase_id}
      {:reply, {:ok, codebase_id}, updated_state}
    else
      {:reply, {:error, :codebase_not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_active_codebase, _from, state) do
    active_codebase = Map.get(state.codebases, state.active_codebase)
    {:reply, {state.active_codebase, active_codebase}, state}
  end

  @impl true
  def handle_call({:analyze_codebase, codebase_id}, _from, state) do
    case Map.get(state.codebases, codebase_id) do
      nil ->
        {:reply, {:error, :codebase_not_found}, state}

      codebase_data ->
        analysis_result = perform_codebase_analysis(codebase_id, codebase_data)

        Task.start(fn ->
          case MetricsPipeline.analyze_codebase(codebase_id, project_id: codebase_id) do
            {:ok, execution_id} ->
              Logger.info("Triggered code metrics workflow",
                codebase_id: codebase_id,
                execution_id: execution_id
              )

            {:error, reason} ->
              Logger.error("Failed to trigger code metrics workflow",
                codebase_id: codebase_id,
                reason: inspect(reason)
              )

            results when is_list(results) ->
              Logger.info("Synchronous metrics analysis completed",
                codebase_id: codebase_id,
                results: length(results)
              )
          end
        end)

        {:reply, {:ok, analysis_result}, state}
    end
  end

  @impl true
  def handle_call({:compare_codebases, codebase_id_1, codebase_id_2}, _from, state) do
    with {:ok, codebase_1} <- get_codebase_data(state.codebases, codebase_id_1),
         {:ok, codebase_2} <- get_codebase_data(state.codebases, codebase_id_2) do
      comparison_result =
        perform_codebase_comparison(codebase_id_1, codebase_1, codebase_id_2, codebase_2)

      {:reply, {:ok, comparison_result}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_analysis, codebase_id}, _from, state) do
    analysis_path = get_analysis_path(state.root, codebase_id)

    analysis_data =
      case File.read(analysis_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, data} -> data
            _ -> nil
          end

        _ ->
          nil
      end

    {:reply, analysis_data, state}
  end

  @impl true
  def handle_call(:generate_refactoring_plan, _from, state) do
    with {:ok, singularity_analysis} <- get_codebase_analysis(state, "singularity"),
         {:ok, engine_analysis} <- get_codebase_analysis(state, "singularity-engine") do
      refactoring_plan =
        generate_refactoring_plan_from_analyses(singularity_analysis, engine_analysis)

      {:reply, {:ok, refactoring_plan}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_training_samples, language, min_length, limit}, _from, state) do
    samples = collect_training_samples(state, language, min_length, limit)
    {:reply, samples, state}
  end

  @impl true
  def handle_cast({:save_vision, vision_data}, state) do
    vision_path = Path.join(state.root, "vision.json")

    json = Jason.encode!(vision_data, pretty: true)
    File.write!(vision_path, json)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:save_queue, agent_id, entries}, state) when is_list(entries) do
    queue_path = queue_path(state.queues, agent_id)

    if entries == [] do
      File.rm(queue_path)
      {:noreply, state}
    else
      payload =
        entries
        |> Enum.map(&queue_entry_to_map/1)
        |> Enum.reject(&is_nil/1)
        |> Jason.encode!()

      :ok = File.write(queue_path, payload)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:store_analysis, codebase_id, analysis_data}, state) do
    analysis_path = get_analysis_path(state.root, codebase_id)
    analysis_dir = Path.dirname(analysis_path)

    with :ok <- File.mkdir_p(analysis_dir),
         {:ok, json} <- Jason.encode(analysis_data, pretty: true),
         :ok <- File.write(analysis_path, json) do
      :ok
    else
      {:error, reason} ->
        require Logger
        Logger.error("Failed to store analysis: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_old_versions, state) do
    cleanup_old_versions(state.versions)
    schedule_cleanup()
    {:noreply, state}
  end

  defp queue_path(dir, agent_id), do: Path.join(dir, "#{agent_id}.json")

  defp queue_entry_to_map(%{payload: payload, context: context, inserted_at: inserted_at} = entry) do
    %{
      "payload" => payload,
      "context" => context,
      "inserted_at" => inserted_at,
      "fingerprint" => Map.get(entry, :fingerprint)
    }
  end

  defp queue_entry_to_map(queue_entry) when is_map(queue_entry) do
    # Convert queue entry to map format
    %{
      "id" => Map.get(queue_entry, :id),
      "payload" => Map.get(queue_entry, :payload),
      "context" => Map.get(queue_entry, :context),
      "inserted_at" => Map.get(queue_entry, :inserted_at),
      "status" => Map.get(queue_entry, :status, "pending")
    }
  end
  defp queue_entry_to_map(_), do: nil

  defp map_to_queue_entry(
         %{"payload" => payload, "context" => context, "inserted_at" => ts} = map
       )
       when is_integer(ts) do
    %{
      payload: payload,
      context: context,
      inserted_at: ts,
      fingerprint: Map.get(map, "fingerprint")
    }
  end

  defp map_to_queue_entry(map) when is_map(map) do
    # Convert map to queue entry format
    %{
      payload: Map.get(map, "payload"),
      context: Map.get(map, "context"),
      inserted_at: Map.get(map, "inserted_at"),
      fingerprint: Map.get(map, "fingerprint"),
      status: Map.get(map, "status", "pending")
    }
  end
  defp map_to_queue_entry(_), do: nil

  defp ensure_dir(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp stringify_keys(%{} = map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, stringify_keys(value)}
      {key, value} -> {to_string(key), stringify_keys(value)}
    end)
    |> Enum.into(%{})
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(other), do: other

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_versions, @cleanup_interval_ms)
  end

  defp cleanup_old_versions(versions_dir) do
    cutoff_time = System.system_time(:second) - @version_ttl_hours * 3600

    case File.ls(versions_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".exs"))
        |> Enum.each(&cleanup_file(&1, versions_dir, cutoff_time))

      _ ->
        :ok
    end
  end

  defp cleanup_file(file, versions_dir, cutoff_time) do
    path = Path.join(versions_dir, file)

    case File.stat(path) do
      {:ok, %{mtime: mtime}} ->
        file_time = :calendar.datetime_to_gregorian_seconds(mtime)

        if file_time < cutoff_time do
          File.rm(path)
          File.rm(Path.rootname(path) <> ".json")
        end

      _ ->
        :ok
    end
  end

  # Helper functions for codebase analysis
  defp get_codebase_data(codebases, codebase_id) do
    case Map.get(codebases, codebase_id) do
      nil -> {:error, :codebase_not_found}
      data -> {:ok, data}
    end
  end

  defp perform_codebase_analysis(codebase_id, codebase_data) do
    %{
      codebase_id: codebase_id,
      path: codebase_data.path,
      type: codebase_data.type,
      analysis_timestamp: DateTime.utc_now(),
      file_structure: analyze_file_structure(codebase_data.path),
      technologies: analyze_technologies(codebase_data.path),
      architecture_patterns: analyze_architecture_patterns(codebase_data.path),
      services: analyze_services(codebase_data.path),
      completion_status: analyze_completion_status(codebase_data.path),
      # Advanced analysis for complex codebases like singularity-engine
      service_consolidation_analysis: analyze_service_consolidation(codebase_data.path),
      dependency_graph: analyze_dependency_graph(codebase_data.path),
      domain_analysis: analyze_domains(codebase_data.path),
      build_system_analysis: analyze_build_systems(codebase_data.path),
      deployment_analysis: analyze_deployment_patterns(codebase_data.path),
      messaging_analysis: analyze_messaging_patterns(codebase_data.path),
      database_analysis: analyze_database_patterns(codebase_data.path),
      security_analysis: analyze_security_patterns(codebase_data.path),
      monitoring_analysis: analyze_monitoring_patterns(codebase_data.path),
      ai_framework_analysis: analyze_ai_frameworks(codebase_data.path),
      sandbox_analysis: analyze_sandbox_patterns(codebase_data.path),
      bpmn_analysis: analyze_bpmn_patterns(codebase_data.path)
    }
  end

  defp analyze_file_structure(codebase_path) do
    if File.exists?(codebase_path) do
      files =
        Path.wildcard(Path.join(codebase_path, "**/*"))
        |> Enum.reject(&File.dir?/1)
        |> Enum.map(&Path.relative_to(&1, codebase_path))

      %{
        total_files: length(files),
        file_types: group_files_by_type(files)
      }
    else
      %{total_files: 0, file_types: %{}}
    end
  end

  defp group_files_by_type(files) do
    Enum.group_by(files, fn file ->
      Path.extname(file)
      |> case do
        "" -> :no_extension
        ext -> String.to_atom(ext)
      end
    end)
    |> Enum.map(fn {type, files} -> {type, length(files)} end)
    |> Enum.into(%{})
  end

  defp analyze_technologies(codebase_path) do
    # Use advanced technology detection with confidence scoring
    detection_result =
      Singularity.ArchitectureEngine.Detectors.TechnologyDetector.detect_technologies(
        codebase_path
      )

    case detection_result do
      {:ok, result} ->
        # Extract technologies with confidence scores
        extract_technologies_from_detection(result.technologies)

      {:error, _reason} ->
        # Fallback to basic detection
        basic_technology_detection(codebase_path)
    end
  end

  defp extract_technologies_from_detection(technologies_map) do
    # Extract high-confidence technologies (>0.7 confidence)
    Enum.flat_map(technologies_map, fn {_category, techs} ->
      case techs do
        list when is_list(list) ->
          Enum.map(list, fn tech ->
            case tech do
              %{name: name, confidence: confidence} when confidence > 0.7 ->
                String.to_atom(name)

              name when is_atom(name) ->
                name

              _ ->
                nil
            end
          end)

        _ ->
          []
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp basic_technology_detection(codebase_path) do
    technologies = []

    # Check for package.json (Node.js/TypeScript)
    technologies =
      if File.exists?(Path.join(codebase_path, "package.json")) do
        [:nodejs, :typescript | technologies]
      else
        technologies
      end

    # Check for Cargo.toml (Rust)
    technologies =
      if File.exists?(Path.join(codebase_path, "Cargo.toml")) do
        [:rust | technologies]
      else
        technologies
      end

    # Check for mix.exs (Elixir)
    technologies =
      if File.exists?(Path.join(codebase_path, "mix.exs")) do
        [:elixir | technologies]
      else
        technologies
      end

    # Check for requirements.txt (Python)
    technologies =
      if File.exists?(Path.join(codebase_path, "requirements.txt")) do
        [:python | technologies]
      else
        technologies
      end

    # Check for go.mod (Go)
    technologies =
      if File.exists?(Path.join(codebase_path, "go.mod")) do
        [:go | technologies]
      else
        technologies
      end

    technologies
  end

  defp analyze_architecture_patterns(codebase_path) do
    patterns = []

    # Check for microservices pattern
    services_dir = Path.join(codebase_path, "services")

    patterns =
      if File.exists?(services_dir) and File.dir?(services_dir) do
        [:microservices | patterns]
      else
        patterns
      end

    # Check for domain-driven design
    domains_dir = Path.join(codebase_path, "domains")

    patterns =
      if File.exists?(domains_dir) and File.dir?(domains_dir) do
        [:domain_driven_design | patterns]
      else
        patterns
      end

    # Check for monorepo pattern
    patterns =
      if File.exists?(Path.join(codebase_path, "nx.json")) or
           File.exists?(Path.join(codebase_path, "lerna.json")) or
           File.exists?(Path.join(codebase_path, "moon.yml")) do
        [:monorepo | patterns]
      else
        patterns
      end

    # Deep monorepo analysis
    monorepo_analysis =
      if :monorepo in patterns do
        analyze_monorepo_structure(codebase_path)
      else
        %{}
      end

    %{
      patterns: patterns,
      monorepo_analysis: monorepo_analysis,
      domain_boundaries: analyze_domain_boundaries(codebase_path),
      service_separation: analyze_service_separation(codebase_path),
      architectural_layers: analyze_architectural_layers(codebase_path)
    }
  end

  defp analyze_domain_boundaries(codebase_path) do
    lib_dir = Path.join(codebase_path, "lib")

    domains =
      case File.ls(lib_dir) do
        {:ok, entries} ->
          entries
          |> Enum.filter(&File.dir?(Path.join(lib_dir, &1)))
          |> Enum.map(fn entry ->
            %{
              domain: entry,
              module_path: Path.join(lib_dir, entry)
            }
          end)

        _ ->
          []
      end

    %{
      domains: domains,
      detected_at: DateTime.utc_now()
    }
  end

  defp analyze_service_separation(codebase_path) do
    services_dir = Path.join(codebase_path, "services")

    services =
      case File.ls(services_dir) do
        {:ok, entries} ->
          entries
          |> Enum.filter(&File.dir?(Path.join(services_dir, &1)))
          |> Enum.map(fn entry ->
            path = Path.join(services_dir, entry)

            %{
              service: entry,
              has_lib?: File.dir?(Path.join(path, "lib")),
              has_tests?: File.dir?(Path.join(path, "test"))
            }
          end)

        _ ->
          []
      end

    %{
      service_count: length(services),
      services: services
    }
  end

  defp analyze_architectural_layers(codebase_path) do
    lib_dir = Path.join(codebase_path, "lib")

    base_layers = %{
      presentation: [],
      domain: [],
      infrastructure: []
    }

    layers =
      case File.ls(lib_dir) do
        {:ok, entries} ->
          Enum.reduce(entries, base_layers, fn entry, acc ->
            down = String.downcase(entry)
            path = Path.join(lib_dir, entry)

            cond do
              not File.dir?(path) ->
                acc

              String.contains?(down, "web") or String.contains?(down, "ui") ->
                Map.update!(acc, :presentation, &[entry | &1])

              String.contains?(down, "infra") or String.contains?(down, "adapter") ->
                Map.update!(acc, :infrastructure, &[entry | &1])

              true ->
                Map.update!(acc, :domain, &[entry | &1])
            end
          end)

        _ ->
          base_layers
      end

    %{layers: layers, analyzed_at: DateTime.utc_now()}
  end

  defp analyze_monorepo_structure(codebase_path) do
    dirs =
      ["apps", "services", "packages"]
      |> Enum.map(fn dir -> {dir, Path.join(codebase_path, dir)} end)
      |> Enum.map(fn {name, path} -> {name, list_subdirs(path)} end)

    %{structure: dirs, analyzed_at: DateTime.utc_now()}
  end

  defp list_subdirs(path) do
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&File.dir?(Path.join(path, &1)))
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp analyze_services(codebase_path) do
    services = []

    # Look for services in services/ directory
    services_dir = Path.join(codebase_path, "services")

    services =
      if File.exists?(services_dir) do
        services ++ find_services_in_directory(services_dir)
      else
        services
      end

    # Look for services in apps/ directory (umbrella project)
    apps_dir = Path.join(codebase_path, "apps")

    services =
      if File.exists?(apps_dir) do
        services ++ find_services_in_directory(apps_dir)
      else
        services
      end

    services
  end

  defp find_services_in_directory(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.map(entries, fn entry ->
          service_path = Path.join(dir, entry)

          %{
            name: entry,
            path: service_path,
            type: determine_service_type(service_path),
            language: determine_service_language(service_path)
          }
        end)

      _ ->
        []
    end
  end

  defp determine_service_type(service_path) do
    cond do
      File.exists?(Path.join(service_path, "package.json")) -> :nestjs
      File.exists?(Path.join(service_path, "Cargo.toml")) -> :rust_service
      File.exists?(Path.join(service_path, "requirements.txt")) -> :fastapi
      File.exists?(Path.join(service_path, "go.mod")) -> :go_service
      File.exists?(Path.join(service_path, "mix.exs")) -> :elixir_service
      true -> :unknown
    end
  end

  defp determine_service_language(service_path) do
    cond do
      File.exists?(Path.join(service_path, "package.json")) -> :typescript
      File.exists?(Path.join(service_path, "Cargo.toml")) -> :rust
      File.exists?(Path.join(service_path, "requirements.txt")) -> :python
      File.exists?(Path.join(service_path, "go.mod")) -> :go
      File.exists?(Path.join(service_path, "mix.exs")) -> :elixir
      true -> :unknown
    end
  end

  defp analyze_completion_status(codebase_path) do
    # Simple heuristic for completion status
    total_files = count_files_recursive(codebase_path)
    todo_files = count_files_with_todos(codebase_path)

    completion_percentage =
      if total_files > 0 do
        (total_files - todo_files) / total_files * 100
      else
        0.0
      end

    %{
      total_files: total_files,
      files_with_todos: todo_files,
      completion_percentage: Float.round(completion_percentage, 2)
    }
  end

  defp count_files_recursive(path) do
    if File.exists?(path) do
      Path.wildcard(Path.join(path, "**/*"))
      |> Enum.reject(&File.dir?/1)
      |> length()
    else
      0
    end
  end

  defp count_files_with_todos(path) do
    if File.exists?(path) do
      Path.wildcard(Path.join(path, "**/*.{ts,js,rs,py,go,ex,exs}"))
      |> Enum.count(fn file ->
        case File.read(file) do
          {:ok, content} -> String.contains?(String.downcase(content), "todo")
          _ -> false
        end
      end)
    else
      0
    end
  end

  defp perform_codebase_comparison(id1, data1, id2, data2) do
    analysis1 = perform_codebase_analysis(id1, data1)
    analysis2 = perform_codebase_analysis(id2, data2)

    %{
      codebase_1: analysis1,
      codebase_2: analysis2,
      technology_differences:
        compare_technologies(analysis1.technologies, analysis2.technologies),
      architecture_differences:
        compare_architectures(analysis1.architecture_patterns, analysis2.architecture_patterns),
      service_differences: compare_services(analysis1.services, analysis2.services),
      completion_differences:
        compare_completion(analysis1.completion_status, analysis2.completion_status)
    }
  end

  defp compare_technologies(tech1, tech2) do
    %{
      common: Enum.filter(tech1, &(&1 in tech2)),
      only_in_1: Enum.filter(tech1, &(&1 not in tech2)),
      only_in_2: Enum.filter(tech2, &(&1 not in tech1))
    }
  end

  defp compare_architectures(arch1, arch2) do
    %{
      common: Enum.filter(arch1, &(&1 in arch2)),
      only_in_1: Enum.filter(arch1, &(&1 not in arch2)),
      only_in_2: Enum.filter(arch2, &(&1 not in arch1))
    }
  end

  defp compare_services(services1, services2) do
    %{
      common_services: find_common_services(services1, services2),
      services_only_in_1: find_unique_services(services1, services2),
      services_only_in_2: find_unique_services(services2, services1)
    }
  end

  defp find_common_services(services1, services2) do
    names1 = MapSet.new(Enum.map(services1, & &1.name))
    names2 = MapSet.new(Enum.map(services2, & &1.name))

    MapSet.intersection(names1, names2)
    |> MapSet.to_list()
  end

  defp find_unique_services(services1, services2) do
    names1 = MapSet.new(Enum.map(services1, & &1.name))
    names2 = MapSet.new(Enum.map(services2, & &1.name))

    MapSet.difference(names1, names2)
    |> MapSet.to_list()
  end

  defp compare_completion(completion1, completion2) do
    %{
      completion_1: completion1.completion_percentage,
      completion_2: completion2.completion_percentage,
      difference: completion2.completion_percentage - completion1.completion_percentage
    }
  end

  defp get_codebase_analysis(state, codebase_id) do
    case Map.get(state.codebases, codebase_id) do
      nil -> {:error, :codebase_not_found}
      data -> {:ok, perform_codebase_analysis(codebase_id, data)}
    end
  end

  defp generate_refactoring_plan_from_analyses(singularity_analysis, engine_analysis) do
    %{
      current_state: singularity_analysis,
      target_state: engine_analysis,
      refactoring_steps: generate_refactoring_steps(singularity_analysis, engine_analysis),
      technology_migrations:
        generate_technology_migrations(singularity_analysis, engine_analysis),
      architecture_transformations:
        generate_architecture_transformations(singularity_analysis, engine_analysis),
      estimated_effort: estimate_refactoring_effort(singularity_analysis, engine_analysis)
    }
  end

  defp generate_refactoring_steps(_singularity_analysis, _engine_analysis) do
    [
      %{
        step: 1,
        description: "Analyze current singularity architecture",
        effort_hours: 8
      },
      %{
        step: 2,
        description: "Identify services to consolidate",
        effort_hours: 16
      },
      %{
        step: 3,
        description: "Implement microservices architecture",
        effort_hours: 40
      },
      %{
        step: 4,
        description: "Add domain-driven design patterns",
        effort_hours: 24
      },
      %{
        step: 5,
        description: "Implement pgmq messaging",
        effort_hours: 12
      },
      %{
        step: 6,
        description: "Add Kubernetes deployment",
        effort_hours: 16
      }
    ]
  end

  defp generate_technology_migrations(singularity_analysis, engine_analysis) do
    %{
      technologies_to_add: engine_analysis.technologies -- singularity_analysis.technologies,
      technologies_to_remove: singularity_analysis.technologies -- engine_analysis.technologies,
      technologies_to_keep:
        engine_analysis.technologies --
          (engine_analysis.technologies -- singularity_analysis.technologies)
    }
  end

  defp generate_architecture_transformations(singularity_analysis, engine_analysis) do
    %{
      patterns_to_add:
        engine_analysis.architecture_patterns -- singularity_analysis.architecture_patterns,
      patterns_to_remove:
        singularity_analysis.architecture_patterns -- engine_analysis.architecture_patterns,
      patterns_to_keep:
        engine_analysis.architecture_patterns --
          (engine_analysis.architecture_patterns -- singularity_analysis.architecture_patterns)
    }
  end

  defp estimate_refactoring_effort(singularity_analysis, engine_analysis) do
    # Simple effort estimation based on differences
    technology_diff = length(engine_analysis.technologies -- singularity_analysis.technologies)

    pattern_diff =
      length(engine_analysis.architecture_patterns -- singularity_analysis.architecture_patterns)

    service_diff = length(engine_analysis.services) - length(singularity_analysis.services)

    # Base hours
    base_effort = 100
    technology_effort = technology_diff * 20
    pattern_effort = pattern_diff * 30
    service_effort = abs(service_diff) * 10

    total_effort = base_effort + technology_effort + pattern_effort + service_effort

    %{
      total_hours: total_effort,
      estimated_weeks: Float.ceil(total_effort / 40, 1),
      estimated_months: Float.ceil(total_effort / 160, 1),
      breakdown: %{
        technology_migration: technology_effort,
        architecture_transformation: pattern_effort,
        service_consolidation: service_effort,
        base_refactoring: base_effort
      }
    }
  end

  defp get_analysis_path(root, codebase_id) do
    Path.join(root, "analyses", "#{codebase_id}.json")
  end

  # Advanced analysis functions for complex codebases like singularity-engine

  defp analyze_service_consolidation(codebase_path) do
    # Analyze service consolidation opportunities
    services = analyze_services(codebase_path)

    %{
      total_services: length(services),
      duplicate_services: find_duplicate_services(services),
      consolidation_candidates: identify_consolidation_candidates(services),
      consolidation_plan: generate_consolidation_plan(services)
    }
  end

  defp find_duplicate_services(services) do
    # Find services with similar names or functionality
    Enum.group_by(services, fn service ->
      # Extract base name (remove suffixes like -service, -api, etc.)
      service.name
      |> String.replace(~r/(-service|-api|-client|-server)$/, "")
      |> String.downcase()
    end)
    |> Enum.filter(fn {_base_name, services} -> length(services) > 1 end)
  end

  defp identify_consolidation_candidates(services) do
    # Group services by functionality
    Enum.group_by(services, fn service ->
      extract_service_functionality(service.name)
    end)
  end

  defp extract_service_functionality(service_name) do
    cond do
      String.contains?(service_name, "auth") -> :authentication
      String.contains?(service_name, "user") -> :user_management
      String.contains?(service_name, "data") -> :data_management
      String.contains?(service_name, "api") -> :api_gateway
      String.contains?(service_name, "message") -> :messaging
      String.contains?(service_name, "storage") -> :configuration
      String.contains?(service_name, "monitor") -> :monitoring
      String.contains?(service_name, "log") -> :logging
      String.contains?(service_name, "cache") -> :caching
      true -> :general
    end
  end

  defp generate_consolidation_plan(services) do
    %{
      # Target from singularity-engine analysis
      target_service_count: 25,
      current_service_count: length(services),
      reduction_percentage: Float.round((length(services) - 25) / length(services) * 100, 2),
      consolidation_strategy: "Merge related services by domain"
    }
  end

  defp analyze_dependency_graph(codebase_path) do
    # Analyze service dependencies
    services = analyze_services(codebase_path)

    dependencies =
      Enum.flat_map(services, fn service ->
        analyze_service_dependencies(service)
      end)

    %{
      total_dependencies: length(dependencies),
      circular_dependencies: detect_circular_dependencies(dependencies),
      high_coupling_services: find_high_coupling_services(dependencies),
      dependency_graph: build_dependency_graph(dependencies)
    }
  end

  defp analyze_service_dependencies(service) do
    # Analyze dependencies for a single service
    service_path = service.path

    dependencies =
      case service.language do
        :typescript -> analyze_typescript_dependencies(service_path)
        :rust -> analyze_rust_dependencies(service_path)
        :python -> analyze_python_dependencies(service_path)
        :go -> analyze_go_dependencies(service_path)
        _ -> []
      end

    Enum.map(dependencies, fn dep ->
      %{
        source_service: service.name,
        target_service: dep.target,
        dependency_type: dep.type,
        file_path: dep.file_path
      }
    end)
  end

  defp analyze_typescript_dependencies(service_path) do
    # Scan TypeScript files for imports
    src_path = Path.join(service_path, "src")

    if File.exists?(src_path) do
      Path.wildcard(Path.join(src_path, "**/*.ts"))
      |> Enum.flat_map(&extract_typescript_imports/1)
    else
      []
    end
  end

  defp analyze_rust_dependencies(service_path) do
    # Scan Rust files for use statements
    src_path = Path.join(service_path, "src")

    if File.exists?(src_path) do
      Path.wildcard(Path.join(src_path, "**/*.rs"))
      |> Enum.flat_map(&extract_rust_imports/1)
    else
      []
    end
  end

  defp analyze_python_dependencies(service_path) do
    # Scan Python files for imports
    Path.wildcard(Path.join(service_path, "**/*.py"))
    |> Enum.flat_map(&extract_python_imports/1)
  end

  defp analyze_go_dependencies(service_path) do
    # Scan Go files for imports
    Path.wildcard(Path.join(service_path, "**/*.go"))
    |> Enum.flat_map(&extract_go_imports/1)
  end

  defp extract_typescript_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/import.*from\s+['"]([^'"]+)['"]/, content)
        |> Enum.map(fn [_, import_path] ->
          %{
            target: normalize_import_path(import_path),
            type: :import,
            file_path: file_path
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_rust_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/use\s+([^;]+);/, content)
        |> Enum.map(fn [_, use_path] ->
          %{
            target: normalize_rust_path(use_path),
            type: :use,
            file_path: file_path
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_python_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/import\s+([^\s]+)/, content)
        |> Enum.map(fn [_, import_path] ->
          %{
            target: normalize_python_path(import_path),
            type: :import,
            file_path: file_path
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_go_imports(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/import\s+['"]([^'"]+)['"]/, content)
        |> Enum.map(fn [_, import_path] ->
          %{
            target: normalize_go_path(import_path),
            type: :import,
            file_path: file_path
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp normalize_import_path(path) do
    cond do
      String.starts_with?(path, "./") -> extract_service_name_from_path(path)
      String.starts_with?(path, "../") -> extract_service_name_from_path(path)
      true -> path
    end
  end

  defp normalize_rust_path(path) do
    String.split(path, "::")
    |> List.first()
  end

  defp normalize_python_path(path) do
    String.split(path, ".")
    |> List.first()
  end

  defp normalize_go_path(path) do
    String.split(path, "/")
    |> List.last()
  end

  defp extract_service_name_from_path(path) do
    path
    |> String.replace(~r/^\.\.?\//, "")
    |> String.split("/")
    |> List.first()
  end

  defp detect_circular_dependencies(dependencies) do
    # Simple circular dependency detection
    dependency_map = Enum.group_by(dependencies, & &1.source_service)

    Enum.flat_map(dependency_map, fn {service, deps} ->
      targets = Enum.map(deps, & &1.target_service)
      find_cycles_from_service(service, targets, dependency_map, [])
    end)
    |> Enum.uniq()
  end

  defp find_cycles_from_service(service, targets, dependency_map, visited) do
    if service in visited do
      [visited ++ [service]]
    else
      Enum.flat_map(targets, fn target ->
        target_deps = Map.get(dependency_map, target, [])
        target_targets = Enum.map(target_deps, & &1.target_service)
        find_cycles_from_service(target, target_targets, dependency_map, [service | visited])
      end)
    end
  end

  defp find_high_coupling_services(dependencies) do
    dependency_counts = Enum.frequencies(Enum.map(dependencies, & &1.source_service))

    Enum.filter(dependency_counts, fn {_service, count} -> count > 5 end)
    |> Enum.sort_by(fn {_service, count} -> count end, :desc)
  end

  defp build_dependency_graph(dependencies) do
    Enum.reduce(dependencies, %{}, fn dep, acc ->
      source = dep.source_service
      target = dep.target_service

      acc
      |> Map.update(source, [target], &[target | &1])
      |> Map.update(target, [], & &1)
    end)
  end

  defp analyze_domains(codebase_path) do
    # Analyze domain-driven design structure
    domains_dir = Path.join(codebase_path, "domains")

    if File.exists?(domains_dir) do
      domains =
        case File.ls(domains_dir) do
          {:ok, entries} ->
            Enum.map(entries, fn domain ->
              domain_path = Path.join(domains_dir, domain)
              analyze_domain_structure(domain, domain_path)
            end)

          _ ->
            []
        end

      %{
        total_domains: length(domains),
        domains: domains,
        domain_services: count_domain_services(domains)
      }
    else
      %{total_domains: 0, domains: [], domain_services: 0}
    end
  end

  defp analyze_domain_structure(domain_name, domain_path) do
    %{
      name: domain_name,
      path: domain_path,
      services: find_services_in_directory(domain_path),
      has_readme: File.exists?(Path.join(domain_path, "README.md")),
      consolidation_status: analyze_domain_consolidation(domain_path)
    }
  end

  defp analyze_domain_consolidation(domain_path) do
    # Check for consolidation documentation
    consolidation_files = [
      "CONSOLIDATION_PLAN.md",
      "SERVICE_CONSOLIDATION.md",
      "MERGE_PLAN.md"
    ]

    consolidation_found =
      Enum.any?(consolidation_files, fn file ->
        File.exists?(Path.join(domain_path, file))
      end)

    %{
      has_consolidation_plan: consolidation_found,
      consolidation_files:
        Enum.filter(consolidation_files, fn file ->
          File.exists?(Path.join(domain_path, file))
        end)
    }
  end

  defp count_domain_services(domains) do
    Enum.sum(
      Enum.map(domains, fn domain ->
        length(domain.services)
      end)
    )
  end

  defp analyze_build_systems(codebase_path) do
    build_systems = []

    # Check for Bazel
    build_systems =
      if File.exists?(Path.join(codebase_path, "WORKSPACE")) or
           File.exists?(Path.join(codebase_path, "MODULE.bazel")) do
        [:bazel | build_systems]
      else
        build_systems
      end

    # Check for Nx
    build_systems =
      if File.exists?(Path.join(codebase_path, "nx.json")) do
        [:nx | build_systems]
      else
        build_systems
      end

    # Check for Moon
    build_systems =
      if File.exists?(Path.join(codebase_path, "moon.yml")) do
        [:moon | build_systems]
      else
        build_systems
      end

    # Check for Lerna
    build_systems =
      if File.exists?(Path.join(codebase_path, "lerna.json")) do
        [:lerna | build_systems]
      else
        build_systems
      end

    %{
      build_systems: build_systems,
      primary_build_system: List.first(build_systems),
      build_configuration: analyze_build_configuration(codebase_path, build_systems)
    }
  end

  defp analyze_build_configuration(codebase_path, build_systems) do
    Enum.map(build_systems, fn system ->
      case system do
        :bazel -> analyze_bazel_config(codebase_path)
        :nx -> analyze_nx_config(codebase_path)
        :moon -> analyze_moon_config(codebase_path)
        :lerna -> analyze_lerna_config(codebase_path)
        _ -> %{}
      end
    end)
    |> Enum.into(%{})
  end

  defp analyze_bazel_config(codebase_path) do
    %{
      workspace_file: File.exists?(Path.join(codebase_path, "WORKSPACE")),
      module_file: File.exists?(Path.join(codebase_path, "MODULE.bazel")),
      build_files: count_build_files(codebase_path, "BUILD"),
      build_bazel_files: count_build_files(codebase_path, "BUILD.bazel")
    }
  end

  defp analyze_nx_config(codebase_path) do
    nx_json_path = Path.join(codebase_path, "nx.json")

    if File.exists?(nx_json_path) do
      case File.read(nx_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, config} -> %{config: config}
            _ -> %{}
          end

        _ ->
          %{}
      end
    else
      %{}
    end
  end

  defp analyze_moon_config(codebase_path) do
    moon_yml_path = Path.join(codebase_path, "moon.yml")

    if File.exists?(moon_yml_path) do
      %{config_file: moon_yml_path}
    else
      %{}
    end
  end

  defp analyze_lerna_config(codebase_path) do
    lerna_json_path = Path.join(codebase_path, "lerna.json")

    if File.exists?(lerna_json_path) do
      case File.read(lerna_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, config} -> %{config: config}
            _ -> %{}
          end

        _ ->
          %{}
      end
    else
      %{}
    end
  end

  defp count_build_files(codebase_path, pattern) do
    Path.wildcard(Path.join(codebase_path, "**/#{pattern}"))
    |> length()
  end

  defp analyze_deployment_patterns(codebase_path) do
    deployment_patterns = []

    # Check for Kubernetes
    k8s_files = Path.wildcard(Path.join(codebase_path, "**/k8s/**/*.yaml"))

    deployment_patterns =
      case k8s_files do
        [_ | _] -> [:kubernetes | deployment_patterns]
        [] -> deployment_patterns
      end

    # Check for Docker
    docker_files = Path.wildcard(Path.join(codebase_path, "**/Dockerfile"))

    deployment_patterns =
      case docker_files do
        [_ | _] -> [:docker | deployment_patterns]
        [] -> deployment_patterns
      end

    # Check for Docker Compose
    compose_files = Path.wildcard(Path.join(codebase_path, "**/docker-compose*.yml"))

    deployment_patterns =
      case compose_files do
        [_ | _] -> [:docker_compose | deployment_patterns]
        [] -> deployment_patterns
      end

    # Check for Helm
    helm_files = Path.wildcard(Path.join(codebase_path, "**/Chart.yaml"))

    deployment_patterns =
      case helm_files do
        [_ | _] -> [:helm | deployment_patterns]
        [] -> deployment_patterns
      end

    # Check for Fly.io
    fly_files = Path.wildcard(Path.join(codebase_path, "**/fly.toml"))

    deployment_patterns =
      case fly_files do
        [_ | _] -> [:fly_io | deployment_patterns]
        [] -> deployment_patterns
      end

    %{
      deployment_patterns: deployment_patterns,
      kubernetes_manifests: length(k8s_files),
      docker_files: length(docker_files),
      helm_charts: length(helm_files),
      fly_configs: length(fly_files)
    }
  end

  defp analyze_messaging_patterns(codebase_path) do
    messaging_patterns = []

    # Check for pgmq
    messaging_patterns =
      if find_pgmq_patterns(codebase_path) do
        [:pgmq | messaging_patterns]
      else
        messaging_patterns
      end

    # Check for Kafka
    messaging_patterns =
      if find_kafka_patterns(codebase_path) do
        [:kafka | messaging_patterns]
      else
        messaging_patterns
      end

    # Check for Redis
    messaging_patterns =
      if find_redis_patterns(codebase_path) do
        [:redis | messaging_patterns]
      else
        messaging_patterns
      end

    # Check for RabbitMQ
    messaging_patterns =
      if find_rabbitmq_patterns(codebase_path) do
        [:rabbitmq | messaging_patterns]
      else
        messaging_patterns
      end

    %{
      messaging_patterns: messaging_patterns,
      jetstream_enabled: find_jetstream_patterns(codebase_path),
      event_sourcing: find_event_sourcing_patterns(codebase_path),
      cqrs_patterns: find_cqrs_patterns(codebase_path)
    }
  end

  defp find_pgmq_patterns(codebase_path) do
    # Look for pgmq-related files and configurations
    pgmq_files =
      Path.wildcard(Path.join(codebase_path, "**/*pgmq*"))
      |> Enum.filter(&File.exists?/1)

    length(pgmq_files) > 0
  end

  defp find_kafka_patterns(codebase_path) do
    kafka_files =
      Path.wildcard(Path.join(codebase_path, "**/*kafka*"))
      |> Enum.filter(&File.exists?/1)

    length(kafka_files) > 0
  end

  defp find_redis_patterns(codebase_path) do
    redis_files =
      Path.wildcard(Path.join(codebase_path, "**/*redis*"))
      |> Enum.filter(&File.exists?/1)

    length(redis_files) > 0
  end

  defp find_rabbitmq_patterns(codebase_path) do
    rabbitmq_files =
      Path.wildcard(Path.join(codebase_path, "**/*rabbitmq*"))
      |> Enum.filter(&File.exists?/1)

    length(rabbitmq_files) > 0
  end

  defp find_jetstream_patterns(codebase_path) do
    # Look for JetStream-specific patterns
    jetstream_files =
      Path.wildcard(Path.join(codebase_path, "**/*jetstream*"))
      |> Enum.filter(&File.exists?/1)

    length(jetstream_files) > 0
  end

  defp find_event_sourcing_patterns(codebase_path) do
    # Look for event sourcing patterns
    event_files =
      Path.wildcard(Path.join(codebase_path, "**/*event*"))
      |> Enum.filter(&File.exists?/1)

    length(event_files) > 0
  end

  defp find_cqrs_patterns(codebase_path) do
    # Look for CQRS patterns
    cqrs_files =
      Path.wildcard(Path.join(codebase_path, "**/*cqrs*"))
      |> Enum.filter(&File.exists?/1)

    length(cqrs_files) > 0
  end

  defp analyze_database_patterns(codebase_path) do
    database_patterns = []

    # Check for PostgreSQL
    database_patterns =
      if find_postgresql_patterns(codebase_path) do
        [:postgresql | database_patterns]
      else
        database_patterns
      end

    # Check for MongoDB
    database_patterns =
      if find_mongodb_patterns(codebase_path) do
        [:mongodb | database_patterns]
      else
        database_patterns
      end

    # Check for Redis
    database_patterns =
      if find_redis_patterns(codebase_path) do
        [:redis | database_patterns]
      else
        database_patterns
      end

    %{
      database_patterns: database_patterns,
      pgvector_enabled: find_pgvector_patterns(codebase_path),
      connection_pooling: find_connection_pooling_patterns(codebase_path),
      migrations: find_migration_patterns(codebase_path)
    }
  end

  defp find_postgresql_patterns(codebase_path) do
    postgres_files =
      Path.wildcard(Path.join(codebase_path, "**/*postgres*"))
      |> Enum.filter(&File.exists?/1)

    length(postgres_files) > 0
  end

  defp find_mongodb_patterns(codebase_path) do
    mongo_files =
      Path.wildcard(Path.join(codebase_path, "**/*mongo*"))
      |> Enum.filter(&File.exists?/1)

    length(mongo_files) > 0
  end

  defp find_pgvector_patterns(codebase_path) do
    vector_files =
      Path.wildcard(Path.join(codebase_path, "**/*vector*"))
      |> Enum.filter(&File.exists?/1)

    length(vector_files) > 0
  end

  defp find_connection_pooling_patterns(codebase_path) do
    pool_files =
      Path.wildcard(Path.join(codebase_path, "**/*pool*"))
      |> Enum.filter(&File.exists?/1)

    length(pool_files) > 0
  end

  defp find_migration_patterns(codebase_path) do
    migration_files =
      Path.wildcard(Path.join(codebase_path, "**/*migration*"))
      |> Enum.filter(&File.exists?/1)

    length(migration_files) > 0
  end

  defp analyze_security_patterns(codebase_path) do
    security_patterns = []

    # Check for SPIFFE/SPIRE
    security_patterns =
      if find_spiffe_patterns(codebase_path) do
        [:spiffe_spire | security_patterns]
      else
        security_patterns
      end

    # Check for OPA/Kyverno
    security_patterns =
      if find_opa_patterns(codebase_path) do
        [:opa_kyverno | security_patterns]
      else
        security_patterns
      end

    # Check for Falco
    security_patterns =
      if find_falco_patterns(codebase_path) do
        [:falco | security_patterns]
      else
        security_patterns
      end

    # Check for cert-manager
    security_patterns =
      if find_cert_manager_patterns(codebase_path) do
        [:cert_manager | security_patterns]
      else
        security_patterns
      end

    %{
      security_patterns: security_patterns,
      external_secrets: find_external_secrets_patterns(codebase_path),
      network_policies: find_network_policies_patterns(codebase_path),
      rbac_enabled: find_rbac_patterns(codebase_path)
    }
  end

  defp find_spiffe_patterns(codebase_path) do
    spiffe_files =
      Path.wildcard(Path.join(codebase_path, "**/*spiffe*"))
      |> Enum.filter(&File.exists?/1)

    length(spiffe_files) > 0
  end

  defp find_opa_patterns(codebase_path) do
    opa_files =
      Path.wildcard(Path.join(codebase_path, "**/*opa*"))
      |> Enum.filter(&File.exists?/1)

    length(opa_files) > 0
  end

  defp find_falco_patterns(codebase_path) do
    falco_files =
      Path.wildcard(Path.join(codebase_path, "**/*falco*"))
      |> Enum.filter(&File.exists?/1)

    length(falco_files) > 0
  end

  defp find_cert_manager_patterns(codebase_path) do
    cert_files =
      Path.wildcard(Path.join(codebase_path, "**/*cert*"))
      |> Enum.filter(&File.exists?/1)

    length(cert_files) > 0
  end

  defp find_external_secrets_patterns(codebase_path) do
    secrets_files =
      Path.wildcard(Path.join(codebase_path, "**/*secret*"))
      |> Enum.filter(&File.exists?/1)

    length(secrets_files) > 0
  end

  defp find_network_policies_patterns(codebase_path) do
    network_files =
      Path.wildcard(Path.join(codebase_path, "**/*network*"))
      |> Enum.filter(&File.exists?/1)

    length(network_files) > 0
  end

  defp find_rbac_patterns(codebase_path) do
    rbac_files =
      Path.wildcard(Path.join(codebase_path, "**/*rbac*"))
      |> Enum.filter(&File.exists?/1)

    length(rbac_files) > 0
  end

  defp analyze_monitoring_patterns(codebase_path) do
    monitoring_patterns = []

    # Check for Prometheus
    monitoring_patterns =
      if find_prometheus_patterns(codebase_path) do
        [:prometheus | monitoring_patterns]
      else
        monitoring_patterns
      end

    # Check for Grafana
    monitoring_patterns =
      if find_grafana_patterns(codebase_path) do
        [:grafana | monitoring_patterns]
      else
        monitoring_patterns
      end

    # Check for Jaeger
    monitoring_patterns =
      if find_jaeger_patterns(codebase_path) do
        [:jaeger | monitoring_patterns]
      else
        monitoring_patterns
      end

    # Check for OpenTelemetry
    monitoring_patterns =
      if find_otel_patterns(codebase_path) do
        [:opentelemetry | monitoring_patterns]
      else
        monitoring_patterns
      end

    %{
      monitoring_patterns: monitoring_patterns,
      observability_stack: analyze_observability_stack(codebase_path),
      alerting_enabled: find_alerting_patterns(codebase_path),
      metrics_collection: find_metrics_patterns(codebase_path)
    }
  end

  defp find_prometheus_patterns(codebase_path) do
    prometheus_files =
      Path.wildcard(Path.join(codebase_path, "**/*prometheus*"))
      |> Enum.filter(&File.exists?/1)

    length(prometheus_files) > 0
  end

  defp find_grafana_patterns(codebase_path) do
    grafana_files =
      Path.wildcard(Path.join(codebase_path, "**/*grafana*"))
      |> Enum.filter(&File.exists?/1)

    length(grafana_files) > 0
  end

  defp find_jaeger_patterns(codebase_path) do
    jaeger_files =
      Path.wildcard(Path.join(codebase_path, "**/*jaeger*"))
      |> Enum.filter(&File.exists?/1)

    length(jaeger_files) > 0
  end

  defp find_otel_patterns(codebase_path) do
    otel_files =
      Path.wildcard(Path.join(codebase_path, "**/*otel*"))
      |> Enum.filter(&File.exists?/1)

    length(otel_files) > 0
  end

  defp analyze_observability_stack(codebase_path) do
    %{
      tracing: find_tracing_patterns(codebase_path),
      logging: find_logging_patterns(codebase_path),
      metrics: find_metrics_patterns(codebase_path)
    }
  end

  defp find_tracing_patterns(codebase_path) do
    tracing_files =
      Path.wildcard(Path.join(codebase_path, "**/*trace*"))
      |> Enum.filter(&File.exists?/1)

    length(tracing_files) > 0
  end

  defp find_logging_patterns(codebase_path) do
    logging_files =
      Path.wildcard(Path.join(codebase_path, "**/*log*"))
      |> Enum.filter(&File.exists?/1)

    length(logging_files) > 0
  end

  defp find_metrics_patterns(codebase_path) do
    metrics_files =
      Path.wildcard(Path.join(codebase_path, "**/*metric*"))
      |> Enum.filter(&File.exists?/1)

    length(metrics_files) > 0
  end

  defp find_alerting_patterns(codebase_path) do
    alerting_files =
      Path.wildcard(Path.join(codebase_path, "**/*alert*"))
      |> Enum.filter(&File.exists?/1)

    length(alerting_files) > 0
  end

  defp analyze_ai_frameworks(codebase_path) do
    ai_frameworks = []

    # Check for LangChain
    ai_frameworks =
      if find_langchain_patterns(codebase_path) do
        [:langchain | ai_frameworks]
      else
        ai_frameworks
      end

    # Check for CrewAI
    ai_frameworks =
      if find_crewai_patterns(codebase_path) do
        [:crewai | ai_frameworks]
      else
        ai_frameworks
      end

    # Check for MCP
    ai_frameworks =
      if find_mcp_patterns(codebase_path) do
        [:mcp | ai_frameworks]
      else
        ai_frameworks
      end

    # Check for Custom AIFlow
    ai_frameworks =
      if find_aiflow_patterns(codebase_path) do
        [:aiflow | ai_frameworks]
      else
        ai_frameworks
      end

    %{
      ai_frameworks: ai_frameworks,
      framework_agnostic: find_framework_agnostic_patterns(codebase_path),
      llm_integration: find_llm_integration_patterns(codebase_path)
    }
  end

  defp find_langchain_patterns(codebase_path) do
    langchain_files =
      Path.wildcard(Path.join(codebase_path, "**/*langchain*"))
      |> Enum.filter(&File.exists?/1)

    length(langchain_files) > 0
  end

  defp find_crewai_patterns(codebase_path) do
    crewai_files =
      Path.wildcard(Path.join(codebase_path, "**/*crewai*"))
      |> Enum.filter(&File.exists?/1)

    length(crewai_files) > 0
  end

  defp find_mcp_patterns(codebase_path) do
    mcp_files =
      Path.wildcard(Path.join(codebase_path, "**/*mcp*"))
      |> Enum.filter(&File.exists?/1)

    length(mcp_files) > 0
  end

  defp find_aiflow_patterns(codebase_path) do
    aiflow_files =
      Path.wildcard(Path.join(codebase_path, "**/*aiflow*"))
      |> Enum.filter(&File.exists?/1)

    length(aiflow_files) > 0
  end

  defp find_framework_agnostic_patterns(codebase_path) do
    agnostic_files =
      Path.wildcard(Path.join(codebase_path, "**/*agnostic*"))
      |> Enum.filter(&File.exists?/1)

    length(agnostic_files) > 0
  end

  defp find_llm_integration_patterns(codebase_path) do
    llm_files =
      Path.wildcard(Path.join(codebase_path, "**/*llm*"))
      |> Enum.filter(&File.exists?/1)

    length(llm_files) > 0
  end

  defp analyze_sandbox_patterns(codebase_path) do
    sandbox_patterns = []

    # Check for E2B
    sandbox_patterns =
      if find_e2b_patterns(codebase_path) do
        [:e2b | sandbox_patterns]
      else
        sandbox_patterns
      end

    # Check for Firecracker
    sandbox_patterns =
      if find_firecracker_patterns(codebase_path) do
        [:firecracker | sandbox_patterns]
      else
        sandbox_patterns
      end

    # Check for Modal
    sandbox_patterns =
      if find_modal_patterns(codebase_path) do
        [:modal | sandbox_patterns]
      else
        sandbox_patterns
      end

    %{
      sandbox_patterns: sandbox_patterns,
      dynamic_execution: find_dynamic_execution_patterns(codebase_path),
      code_isolation: find_code_isolation_patterns(codebase_path)
    }
  end

  defp find_e2b_patterns(codebase_path) do
    e2b_files =
      Path.wildcard(Path.join(codebase_path, "**/*e2b*"))
      |> Enum.filter(&File.exists?/1)

    length(e2b_files) > 0
  end

  defp find_firecracker_patterns(codebase_path) do
    firecracker_files =
      Path.wildcard(Path.join(codebase_path, "**/*firecracker*"))
      |> Enum.filter(&File.exists?/1)

    length(firecracker_files) > 0
  end

  defp find_modal_patterns(codebase_path) do
    modal_files =
      Path.wildcard(Path.join(codebase_path, "**/*modal*"))
      |> Enum.filter(&File.exists?/1)

    length(modal_files) > 0
  end

  defp find_dynamic_execution_patterns(codebase_path) do
    dynamic_files =
      Path.wildcard(Path.join(codebase_path, "**/*dynamic*"))
      |> Enum.filter(&File.exists?/1)

    length(dynamic_files) > 0
  end

  defp find_code_isolation_patterns(codebase_path) do
    isolation_files =
      Path.wildcard(Path.join(codebase_path, "**/*isolation*"))
      |> Enum.filter(&File.exists?/1)

    length(isolation_files) > 0
  end

  defp analyze_bpmn_patterns(codebase_path) do
    bpmn_patterns = []

    # Check for BPMN files
    bpmn_files = Path.wildcard(Path.join(codebase_path, "**/*.bpmn"))

    bpmn_patterns =
      case bpmn_files do
        [_ | _] -> [:bpmn | bpmn_patterns]
        [] -> bpmn_patterns
      end

    # Check for workflow engines
    bpmn_patterns =
      if find_workflow_engine_patterns(codebase_path) do
        [:workflow_engine | bpmn_patterns]
      else
        bpmn_patterns
      end

    %{
      bpmn_patterns: bpmn_patterns,
      bpmn_files: length(bpmn_files),
      workflow_integration: find_workflow_integration_patterns(codebase_path),
      process_orchestration: find_process_orchestration_patterns(codebase_path)
    }
  end

  defp find_workflow_engine_patterns(codebase_path) do
    workflow_files =
      Path.wildcard(Path.join(codebase_path, "**/*workflow*"))
      |> Enum.filter(&File.exists?/1)

    length(workflow_files) > 0
  end

  defp find_workflow_integration_patterns(codebase_path) do
    integration_files =
      Path.wildcard(Path.join(codebase_path, "**/*integration*"))
      |> Enum.filter(&File.exists?/1)

    length(integration_files) > 0
  end

  defp find_process_orchestration_patterns(codebase_path) do
    orchestration_files =
      Path.wildcard(Path.join(codebase_path, "**/*orchestration*"))
      |> Enum.filter(&File.exists?/1)

    length(orchestration_files) > 0
  end

  defp collect_training_samples(state, language, min_length, limit) do
    # Get all registered codebases
    codebases = Map.values(state.codebases)

    # Collect code samples from all codebases
    all_samples =
      Enum.flat_map(codebases, fn codebase ->
        collect_samples_from_codebase(codebase, language, min_length)
      end)

    # Shuffle and limit results
    all_samples
    |> Enum.shuffle()
    |> Enum.take(limit)
  end

  defp collect_samples_from_codebase(codebase, language, min_length) do
    codebase_path = codebase.path

    if File.exists?(codebase_path) do
      # Find files matching the language
      file_pattern = get_file_pattern_for_language(language)
      files = Path.wildcard(Path.join(codebase_path, "**/*#{file_pattern}"))

      # Read and filter code samples
      Enum.flat_map(files, fn file_path ->
        case File.read(file_path) do
          {:ok, content} ->
            # Split into code blocks (functions, modules, etc.)
            code_blocks = split_into_code_blocks(content, language)

            # Filter by minimum length
            Enum.filter(code_blocks, fn block ->
              String.length(block) >= min_length
            end)

          _ ->
            []
        end
      end)
    else
      []
    end
  end

  defp get_file_pattern_for_language(language) do
    case String.downcase(language) do
      "elixir" -> ".ex"
      "erlang" -> ".erl"
      "javascript" -> ".js"
      "typescript" -> ".ts"
      "python" -> ".py"
      "ruby" -> ".rb"
      "go" -> ".go"
      "rust" -> ".rs"
      "java" -> ".java"
      "c" -> ".c"
      "cpp" -> ".cpp"
      "csharp" -> ".cs"
      _ -> ".*"
    end
  end

  defp split_into_code_blocks(content, language) do
    # Simple approach: split by double newlines and filter out comments/empty lines
    blocks =
      String.split(content, "\n\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.reject(&String.starts_with?(&1, "//"))
      |> Enum.reject(&String.starts_with?(&1, "/*"))
      |> Enum.reject(&(&1 == ""))

    # For Elixir specifically, try to extract function definitions
    if String.downcase(language) == "elixir" do
      extract_elixir_functions(content) ++ blocks
    else
      blocks
    end
  end

  defp extract_elixir_functions(content) do
    # Simple regex to extract function definitions
    regex = ~r/def\s+\w+.*?(?=^\s*(def|@|defmodule|end)\s|\z)/ms

    Regex.scan(regex, content)
    |> Enum.map(&List.first/1)
    |> Enum.map(&String.trim/1)
  end

  defp detect_repo_root do
    # Try to detect git root automatically
    case System.cmd("git", ["rev-parse", "--show-toplevel"], cd: __DIR__ |> Path.expand() |> Path.join("../../../../..")) do
      {root, 0} -> String.trim(root)
      _ -> 
        # Fallback: use current working directory or CODE_ROOT env var
        System.get_env("CODE_ROOT") || 
        Path.expand(System.cwd!()) ||
        File.cwd!()
    end
  rescue
    _ -> File.cwd!()
  end
end
