defmodule Mix.Tasks.Build.RustEngines do
  @moduledoc """
  Build all Rust NIF engines automatically.

  This task compiles all Rust engines in packages/ and ensures their .so files
  are available for Elixir compilation.

  ## Usage

      mix build.rust_engines

  This task is automatically run before compilation via the custom compiler.
  Set SKIP_RUST_BUILD=1 to skip Rust builds during development.

  ## Logging

  All build operations are logged via Logger (SASL-compatible) for full traceability.
  Logs include:
  - Engine discovery and path validation
  - Dependency fetching (with cache status)
  - Build progress and completion
  - Error details with full context
  """

  use Mix.Task

  require Logger

  @engines [
    %{name: "parser_engine", crate: "parser_code", path: "packages/parser_engine"},
    %{name: "architecture_engine", crate: "architecture_engine", path: "packages/architecture_engine"},
    %{name: "code_quality_engine", crate: "code_quality_engine", path: "packages/code_quality_engine"},
    %{name: "linting_engine", crate: "linting_engine", path: "packages/linting_engine"},
    %{name: "prompt_engine", crate: "prompt_engine", path: "packages/prompt_engine"}
  ]

  @shortdoc "Build all Rust NIF engines"

  def run(args) do
    Logger.info("Rust engine build task started", skip_build: System.get_env("SKIP_RUST_BUILD") == "1")
    
    # Skip if SKIP_RUST_BUILD env var is set (for faster iteration)
    if System.get_env("SKIP_RUST_BUILD") == "1" do
      Mix.shell().info("⏭️  Skipping Rust engine build (SKIP_RUST_BUILD=1)")
      Logger.info("Rust engine build skipped via SKIP_RUST_BUILD=1")
      :ok
    else
      do_build()
    end
  end

  defp do_build do
    Mix.shell().info("Building Rust NIF engines...")
    Logger.info("Starting Rust NIF engine build", engine_count: length(@engines))

    # Get the root directory (nexus/singularity)
    root_dir = Path.expand("../..", __DIR__)
    Logger.debug("Build root directory", root_dir: root_dir)

    # Check if cargo is available
    cargo_path = System.find_executable("cargo")
    unless cargo_path do
      error_msg = """
      ERROR: cargo not found in PATH

      Rust engines require cargo to build. Please ensure:
      1. You're in a Nix dev-shell (nix develop)
      2. Rust toolchain is installed
      
      To skip Rust builds during development, set SKIP_RUST_BUILD=1
      """
      Logger.error("cargo not found in PATH", path: System.get_env("PATH"))
      Mix.shell().error(error_msg)
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
      Mix.shell().info("✅ All Rust engines built successfully")
      :ok
    else
      failed = Enum.count(results, &(&1 == :error))
      skipped = Enum.count(results, &(&1 == :skip))
      Logger.error("Rust engine build completed with failures", 
        failed_count: failed,
        skipped_count: skipped,
        total_engines: length(@engines))
      Mix.shell().error("⚠️  #{failed} engine(s) failed to build")
      System.halt(1)
    end
  end

  defp build_engine(root_dir, %{name: name, crate: crate, path: engine_path}) do
    full_path = Path.join(root_dir, engine_path)
    Logger.debug("Processing engine", engine: name, crate: crate, path: full_path)

    cond do
      not File.exists?(full_path) ->
        Logger.warning("Engine path not found, skipping", engine: name, path: engine_path)
        Mix.shell().info("⏭️  Skipping #{name}: path not found (#{engine_path})")
        :skip

      not File.exists?(Path.join(full_path, "Cargo.toml")) ->
        Logger.warning("Cargo.toml not found, skipping", engine: name, path: full_path)
        Mix.shell().info("⏭️  Skipping #{name}: Cargo.toml not found")
        :skip

      true ->
        cargo_toml = Path.join(full_path, "Cargo.toml")

        # Step 1: Fetch dependencies (uses cargo cache automatically)
        # This ensures dependencies are available before building
        # Cargo will use cached dependencies if available, only downloading missing ones
        # We suppress output unless there's an error (cargo fetch is quiet if cached)
        Logger.debug("Fetching dependencies", engine: name, manifest: cargo_toml)
        fetch_start = System.monotonic_time()
        
        case System.cmd("cargo", ["fetch", "--manifest-path", cargo_toml],
               cd: full_path,
               stderr_to_stdout: false,
               into: []
             ) do
          {output, 0} ->
            fetch_duration = System.monotonic_time() - fetch_start
            # Dependencies fetched or already cached
            # Only show output if there was actual fetching (not just cache hit)
            if String.contains?(output, "Downloading") or String.contains?(output, "Updating") do
              Logger.info("Dependencies updated", engine: name, duration_ms: System.convert_time_unit(fetch_duration, :native, :millisecond))
              Mix.shell().info("📦 Dependencies updated for #{name}")
            else
              Logger.debug("Dependencies already cached", engine: name, duration_ms: System.convert_time_unit(fetch_duration, :native, :millisecond))
            end
            :ok

          {error_output, fetch_exit_code} ->
            Logger.warning("cargo fetch failed, continuing with build", 
              engine: name, 
              exit_code: fetch_exit_code,
              error: String.slice(to_string(error_output), 0..500))
            # Show error if fetch failed
            Mix.shell().warning("⚠️  cargo fetch failed for #{name} (exit code: #{fetch_exit_code})")
            Mix.shell().info("Continuing with build anyway (cargo build will fetch if needed)...")
            :ok
        end

        # Step 2: Build the engine
        # Cargo build will also use cached dependencies automatically
        Logger.info("Building engine", engine: name, crate: crate, mode: "release")
        build_start = System.monotonic_time()
        Mix.shell().info("🔨 Building #{name} (#{crate})...")
        
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
              Mix.shell().info("✅ Built #{name}: #{so_file}")
              :ok
            else
              Logger.error("Build succeeded but .so file not found", engine: name, crate: crate, search_path: full_path)
              Mix.shell().error("❌ Build succeeded but .so file not found for #{name}")
              :error
            end

          {build_output, exit_code} ->
            build_duration = System.monotonic_time() - build_start
            Logger.error("Build failed", 
              engine: name, 
              exit_code: exit_code,
              duration_ms: System.convert_time_unit(build_duration, :native, :millisecond),
              error_preview: String.slice(to_string(build_output), 0..500))
            Mix.shell().error("❌ Failed to build #{name} (exit code: #{exit_code})")
            :error
        end
    end
  end

  defp find_so_file(engine_path, crate_name) do
    # Look for .so file in target/release (release build)
    patterns = [
      Path.join([engine_path, "target", "release", "*.so"]),
      Path.join([engine_path, "target", "release", "deps", "*.so"]),
      # Also check for target/debug (debug build)
      Path.join([engine_path, "target", "debug", "*.so"]),
      Path.join([engine_path, "target", "debug", "deps", "*.so"])
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.find(fn path ->
      # Match crate name (e.g., parser_code.so or libparser_code.so)
      basename = Path.basename(path)
      String.contains?(basename, crate_name) or String.contains?(basename, "lib#{crate_name}")
    end)
  end
end
