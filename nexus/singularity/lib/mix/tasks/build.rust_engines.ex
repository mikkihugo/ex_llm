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
    %{
      name: "code_quality_engine",
      crate: "code_quality_engine",
      path: "packages/code_quality_engine"
    },
    %{name: "linting_engine", crate: "linting_engine", path: "packages/linting_engine"},
    %{name: "prompt_engine", crate: "prompt_engine", path: "packages/prompt_engine"}
  ]

  @shortdoc "Build all Rust NIF engines"

  def run(_args) do
    Logger.info("Rust engine build task started",
      skip_build: System.get_env("SKIP_RUST_BUILD") == "1"
    )

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
        total_engines: length(@engines)
      )

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
        # Check if we need to rebuild
        so_file = find_so_file(full_path, crate)
        needs_rebuild = needs_rebuild?(full_path, so_file)

        if so_file && not needs_rebuild do
          Logger.debug("Engine already built and up to date", engine: name, so_file: so_file)
          Mix.shell().info("✅ #{name} already built and up to date")
          :ok
        else
          if needs_rebuild do
            Logger.info("Engine source changed, rebuilding", engine: name)
            Mix.shell().info("� #{name} source changed, rebuilding...")
          else
            Logger.info("Engine not built yet, building", engine: name)
            Mix.shell().info("🏗️  Building #{name} for first time...")
          end

          do_build_engine(full_path, name, crate)
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

  defp needs_rebuild?(engine_path, so_file) do
    if so_file && File.exists?(so_file) do
      # Check if any Rust source files are newer than the .so file
      source_newer_than_target?(engine_path, so_file)
    else
      true
    end
  end

  defp source_newer_than_target?(engine_path, target_file) do
    target_mtime = File.stat!(target_file).mtime

    # Check Rust source files in src/ directory
    src_patterns = [
      Path.join([engine_path, "src", "**", "*.rs"]),
      Path.join([engine_path, "Cargo.toml"])
    ]

    src_patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.any?(fn source_file ->
      source_mtime = File.stat!(source_file).mtime
      source_mtime > target_mtime
    end)
  end

  defp do_build_engine(engine_path, name, crate) do
    cargo_toml = Path.join(engine_path, "Cargo.toml")

    try do
      # Step 1: Fetch dependencies (uses cargo cache automatically)
      Logger.debug("Fetching dependencies", engine: name, cargo_toml: cargo_toml)

      fetch_result =
        System.cmd("cargo", ["fetch", "--manifest-path", cargo_toml],
          cd: engine_path,
          stderr_to_stdout: true,
          into: IO.stream(:stdio, :line)
        )

      case fetch_result do
        {_, 0} ->
          Logger.debug("Dependencies fetched", engine: name)

        {output, code} ->
          Logger.warning("Dependency fetch had issues",
            engine: name,
            exit_code: code,
            output: output
          )
      end

      # Step 2: Build the engine (release mode for production .so)
      Logger.info("Building engine", engine: name, crate: crate, path: engine_path)

      build_result =
        System.cmd("cargo", ["build", "--release", "--manifest-path", cargo_toml],
          cd: engine_path,
          stderr_to_stdout: true,
          into: IO.stream(:stdio, :line)
        )

      case build_result do
        {_, 0} ->
          # Verify .so file was created
          so_file = find_so_file(engine_path, crate)

          if so_file && File.exists?(so_file) do
            Logger.info("Engine built successfully", engine: name, so_file: so_file)
            Mix.shell().info("✅ #{name} built successfully")
            :ok
          else
            Logger.error("Build succeeded but .so file not found", engine: name, crate: crate)
            Mix.shell().error("⚠️  #{name}: Build succeeded but .so file not found")
            :error
          end

        {output, code} ->
          Logger.error("Build failed", engine: name, exit_code: code, output: output)
          Mix.shell().error("❌ #{name} build failed (exit code: #{code})")
          :error
      end
    rescue
      e ->
        Logger.error("Build exception",
          engine: name,
          error: inspect(e),
          stacktrace: __STACKTRACE__
        )

        Mix.shell().error("❌ #{name} build failed: #{Exception.message(e)}")
        :error
    end
  end
end
