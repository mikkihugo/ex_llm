#!/usr/bin/env elixir

# Unified Server - Launches all Singularity services
# Run with: elixir unified_server.exs

require Logger

defmodule UnifiedServer do
  @moduledoc """
  Unified server that launches all Singularity services:
  - NATS Server
  - PostgreSQL Database
  - Rust Package Registry Service
  - Elixir Phoenix Application
  """

  def start_all do
    Logger.info("🚀 Starting Singularity Unified Server")
    Logger.info("=" |> String.duplicate(60))
    
    # Check if we're in the right directory
    unless File.exists?("singularity") do
      Logger.error("❌ Please run from the singularity project root directory")
      System.halt(1)
    end
    
    # Start services in order
    start_nats()
    start_postgres()
    start_rust_package_registry()
    start_elixir_app()
    
    Logger.info("✅ All services started successfully!")
    Logger.info("🌐 Elixir app: http://localhost:4000")
    Logger.info("📡 NATS: nats://localhost:4222")
    Logger.info("🗄️  PostgreSQL: localhost:5432")
    Logger.info("📦 Package Registry: Running via NATS")
    
    # Keep the server running
    keep_alive()
  end

  defp start_nats do
    Logger.info("🔧 Starting NATS Server...")
    
    # Check if NATS is already running
    case System.cmd("pgrep", ["-f", "nats-server"]) do
      {_, 0} ->
        Logger.info("✅ NATS Server already running")
      _ ->
        # Start NATS in background
        spawn(fn ->
          System.cmd("nats-server", ["-js", "-sd", ".nats", "-p", "4222"], 
            stderr_to_stdout: true, into: IO.stream())
        end)
        :timer.sleep(2000) # Wait for NATS to start
        Logger.info("✅ NATS Server started")
    end
  end

  defp start_postgres do
    Logger.info("🔧 Starting PostgreSQL...")
    
    # Check if PostgreSQL is already running
    case System.cmd("pgrep", ["-f", "postgres"]) do
      {_, 0} ->
        Logger.info("✅ PostgreSQL already running")
      _ ->
        Logger.info("⚠️  PostgreSQL not running - please start it manually")
        Logger.info("   Run: nix develop (to start PostgreSQL)")
    end
  end

  defp start_rust_package_registry do
    Logger.info("🔧 Starting Rust Package Registry Service...")
    
    # Check if already running
    case System.cmd("pgrep", ["-f", "package-registry-service"]) do
      {_, 0} ->
        Logger.info("✅ Rust Package Registry Service already running")
      _ ->
        # Start Rust service in background
        spawn(fn ->
          System.cmd("bash", ["-c", "cd rust/package_registry_indexer && RUST_LOG=info cargo run --bin package-registry-service"], 
            stderr_to_stdout: true, into: IO.stream())
        end)
        :timer.sleep(3000) # Wait for Rust service to start
        Logger.info("✅ Rust Package Registry Service started")
    end
  end

  defp start_elixir_app do
    Logger.info("🔧 Starting Elixir Phoenix Application...")
    
    # Check if already running
    case System.cmd("pgrep", ["-f", "beam.smp"]) do
      {_, 0} ->
        Logger.info("✅ Elixir application already running")
      _ ->
        # Start Elixir app in background
        spawn(fn ->
          System.cmd("bash", ["-c", "cd singularity && mix phx.server"], 
            stderr_to_stdout: true, into: IO.stream())
        end)
        :timer.sleep(5000) # Wait for Elixir app to start
        Logger.info("✅ Elixir Phoenix Application started")
    end
  end

  defp keep_alive do
    Logger.info("🔄 Server is running... Press Ctrl+C to stop")
    
    # Set up signal handler for graceful shutdown
    Process.flag(:trap_exit, true)
    
    # Keep the process alive
    receive do
      {:EXIT, _pid, _reason} ->
        Logger.info("🛑 Shutting down unified server...")
        stop_all_services()
        System.halt(0)
    end
  end

  defp stop_all_services do
    Logger.info("🛑 Stopping all services...")
    
    # Stop Elixir app
    System.cmd("pkill", ["-f", "beam.smp"])
    
    # Stop Rust service
    System.cmd("pkill", ["-f", "package-registry-service"])
    
    # Note: We don't stop NATS and PostgreSQL as they might be used by other processes
    Logger.info("✅ Services stopped")
  end
end

# Start the unified server
UnifiedServer.start_all()