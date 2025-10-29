defmodule Mix.Compilers.RustEngines do
  @moduledoc """
  Custom Mix compiler that builds Rust NIF engines before Elixir compilation.

  This compiler runs automatically as part of the compiler chain, ensuring
  Rust engines are built before Elixir code tries to load them.

  Respects cache: only rebuilds if source files changed, only downloads
  dependencies if not already cached.

  ## Logging

  All compiler operations are logged via Logger (SASL-compatible) for full traceability.
  """

  @behaviour Mix.Task.Compiler
  
  require Logger

  @engines [
    %{name: "parser_engine", crate: "parser_code", path: "packages/parser_engine"},
    %{name: "code_quality_engine", crate: "code_quality_engine", path: "packages/code_quality_engine"},
    %{name: "linting_engine", crate: "linting_engine", path: "packages/linting_engine"},
    %{name: "prompt_engine", crate: "prompt_engine", path: "packages/prompt_engine"}
  ]

  @impl true
  def run(_args) do
    # Skip if SKIP_RUST_BUILD env var is set
    if System.get_env("SKIP_RUST_BUILD") == "1" do
      Mix.shell().info("??  Skipping Rust engine build (SKIP_RUST_BUILD=1)")
      {:ok, []}
    else
      do_build()
    end
  end

  defp do_build do
    Mix.shell().info("Building Rust NIF engines...")
    Logger.info("Starting Rust NIF engine compiler", engine_count: length(@engines))

    # Get the root directory (nexus/singularity)
    root_dir = Path.expand("../..", __DIR__)
    Logger.debug("Compiler root directory", root_dir: root_dir)

    # Check if cargo is available
    cargo_path = System.find_executable("cargo")
    unless cargo_path do
      Logger.error("cargo not found in PATH", path: System.get_env("PATH"))
      Mix.shell().error("""
      ERROR: cargo not found in PATH

      Rust engines require cargo to build. Please ensure:
      1. You're in a Nix dev-shell (nix develop)
      2. Rust toolchain is installed
      
      To skip Rust builds during development, set SKIP_RUST_BUILD=1
      """)
      System.halt(1)
    end
    
    Logger.debug("cargo found", path: cargo_path)

    results =
      @engines
      |> Enum.map(fn engine ->
        build_engine(root_dir, engine)
      end)
      |> Enum.filter(&(&1 != :ok && &1 != :skip))

    if Enum.empty?(results) do
      Logger.info("All Rust engines built successfully", total_engines: length(@engines))
      Mix.shell().info("? All Rust engines built successfully")
      {:ok, []}
    else
      failed = Enum.count(results, &(&1 == :error))
      skipped = Enum.count(results, &(&1 == :skip))
      Logger.error("Rust engine compiler completed with failures", 
        failed_count: failed,
        skipped_count: skipped,
        total_engines: length(@engines))
      Mix.shell().error("??  #{failed} engine(s) failed to build")
      {:error, []}
    end
  end

  defp build_engine(root_dir, %{name: name, crate: crate, path: engine_path}) do
    full_path = Path.join(root_dir, engine_path)
    Logger.debug("Compiler processing engine", engine: name, crate: crate, path: full_path)

    cond do
      not File.exists?(full_path) ->
        Logger.warning("Engine path not found, skipping", engine: name, path: engine_path)
        Mix.shell().info("??  Skipping #{name}: path not found (#{engine_path})")
        :skip

      not File.exists?(Path.join(full_path, "Cargo.toml")) ->
        Logger.warning("Cargo.toml not found, skipping", engine: name, path: full_path)
        Mix.shell().info("??  Skipping #{name}: Cargo.toml not found")
        :skip

      true ->
        cargo_toml = Path.join(full_path, "Cargo.toml")

        # Check if .so file already exists (respect cache)
        existing_so = find_so_file(full_path, crate)
        if existing_so && File.exists?(existing_so) do
          # Check if source is newer than the .so file (only rebuild if changed)
          source_changed = source_newer_than_target?(full_path, existing_so)
          
          if source_changed do
            Logger.debug("Source changed, rebuilding", engine: name, existing_so: existing_so)
            # Source changed, rebuild
            build_engine_step(name, crate, cargo_toml, full_path)
          else
            # Already built and up-to-date, use cache
            so_stat = File.stat!(existing_so)
            Logger.debug("Using cached build", engine: name, so_file: existing_so, file_size_bytes: so_stat.size, mtime: so_stat.mtime)
            Mix.shell().info("? #{name} already built (using cache)")
            :ok
          end
        else
          Logger.debug("No existing build found, building", engine: name)
          # No existing build, build it
          build_engine_step(name, crate, cargo_toml, full_path)
        end
    end
  end

  defp build_engine_step(name, crate, cargo_toml, full_path) do
    # Step 1: Fetch dependencies (uses cargo cache automatically)
    # cargo fetch is quiet if dependencies are already cached
    Logger.debug("Fetching dependencies", engine: name, manifest: cargo_toml)
    fetch_start = System.monotonic_time()
    
    case System.cmd("cargo", ["fetch", "--manifest-path", cargo_toml],
           cd: full_path,
           stderr_to_stdout: false,
           into: []
         ) do
      {output, 0} ->
        fetch_duration = System.monotonic_time() - fetch_start
        # Only show output if there was actual fetching (not just cache hit)
        if String.contains?(output, "Downloading") or String.contains?(output, "Updating") do
          Logger.info("Dependencies updated", engine: name, duration_ms: System.convert_time_unit(fetch_duration, :native, :millisecond))
          Mix.shell().info("?? Dependencies updated for #{name}")
        else
          Logger.debug("Dependencies already cached", engine: name, duration_ms: System.convert_time_unit(fetch_duration, :native, :millisecond))
        end

      {error_output, fetch_exit_code} ->
        Logger.warning("cargo fetch failed, continuing with build", 
          engine: name, 
          exit_code: fetch_exit_code,
          error: String.slice(to_string(error_output), 0..500))
        # Silently continue - cargo build will fetch if needed
        :ok
    end

    # Step 2: Build the engine (cargo build uses cache automatically)
    Logger.info("Building engine", engine: name, crate: crate, mode: "release")
    build_start = System.monotonic_time()
    Mix.shell().info("?? Building #{name} (#{crate})...")
    
    case System.cmd("cargo", ["build", "--release", "--manifest-path", cargo_toml],
           cd: full_path,
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line)
         ) do
      {_, 0} ->
        build_duration = System.monotonic_time() - build_start
        # Verify .so file exists
        so_file = find_so_file(full_path, crate)

        if so_file do
          so_stat = File.stat!(so_file)
          Logger.info("Engine built successfully", 
            engine: name, 
            so_file: so_file,
            file_size_bytes: so_stat.size,
            duration_ms: System.convert_time_unit(build_duration, :native, :millisecond))
          Mix.shell().info("? Built #{name}: #{so_file}")
          :ok
        else
          Logger.error("Build succeeded but .so file not found", engine: name, crate: crate, search_path: full_path)
          Mix.shell().error("? Build succeeded but .so file not found for #{name}")
          :error
        end

      {build_output, exit_code} ->
        build_duration = System.monotonic_time() - build_start
        Logger.error("Build failed", 
          engine: name, 
          exit_code: exit_code,
          duration_ms: System.convert_time_unit(build_duration, :native, :millisecond),
          error_preview: String.slice(to_string(build_output), 0..500))
        Mix.shell().error("? Failed to build #{name} (exit code: #{exit_code})")
        :error
    end
  end

  defp find_so_file(engine_path, crate_name) do
    patterns = [
      Path.join([engine_path, "target", "release", "*.so"]),
      Path.join([engine_path, "target", "release", "deps", "*.so"]),
      Path.join([engine_path, "target", "debug", "*.so"]),
      Path.join([engine_path, "target", "debug", "deps", "*.so"])
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.find(fn path ->
      basename = Path.basename(path)
      String.contains?(basename, crate_name) or String.contains?(basename, "lib#{crate_name}")
    end)
  end

  defp source_newer_than_target?(engine_path, target_file) do
    target_mtime = File.stat!(target_file).mtime
    
    # Check if any Rust source file is newer than the target
    src_patterns = [
      Path.join([engine_path, "src", "**", "*.rs"]),
      Path.join([engine_path, "Cargo.toml"]),
      Path.join([engine_path, "Cargo.lock"])
    ]
    
    src_patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.any?(fn src_file ->
      File.stat!(src_file).mtime > target_mtime
    end)
  end

  @impl true
  def manifests, do: []

  @impl true
  def clean, do: :ok
end
