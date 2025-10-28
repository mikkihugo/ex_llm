defmodule Singularity.BeamAnalysisEngine do
  @moduledoc """
  BEAM Analysis Engine - Comprehensive analysis for BEAM languages

  Provides specialized analysis for Elixir, Erlang, and Gleam including:
  - OTP pattern detection (GenServer, Supervisor, Application)
  - Actor model analysis (process spawning, message passing)
  - Fault tolerance patterns (try/catch, rescue, let it crash)
  - BEAM-specific metrics (process count, message queue analysis)
  - Language-specific features (Phoenix, Ecto, LiveView, etc.)

  ## Usage

      # Analyze Elixir code
      {:ok, analysis} = BeamAnalysisEngine.analyze_beam_code("elixir", code, file_path)

      # Get OTP patterns
      otp_patterns = analysis.otp_patterns
      genservers = otp_patterns.genservers
      supervisors = otp_patterns.supervisors

      # Get actor analysis
      actor_analysis = analysis.actor_analysis
      process_spawning = actor_analysis.process_spawning
      message_passing = actor_analysis.message_passing

      # Get language-specific features
      elixir_features = analysis.language_features.elixir
      phoenix_usage = elixir_features.phoenix_usage
  """

  require Logger

  alias Singularity.Monitoring.CodeEngineHealthTracker

  @supported_beam_languages ["elixir", "erlang", "gleam"]

  @doc """
  Analyze BEAM code for patterns, metrics, and language-specific features.

  ## Parameters

  - `language` - BEAM language ("elixir", "erlang", "gleam")
  - `code` - Source code content
  - `file_path` - File path for context

  ## Returns

  `{:ok, analysis_result}` or `{:error, reason}`

  ## Examples

      # Analyze Elixir code
      {:ok, analysis} = BeamAnalysisEngine.analyze_beam_code("elixir", code, "lib/my_app.ex")

      # Analyze Erlang code
      {:ok, analysis} = BeamAnalysisEngine.analyze_beam_code("erlang", code, "src/my_app.erl")

      # Analyze Gleam code
      {:ok, analysis} = BeamAnalysisEngine.analyze_beam_code("gleam", code, "src/my_app.gleam")
  """
  def analyze_beam_code(language, code, file_path) when language in @supported_beam_languages do
    Logger.info("Analyzing BEAM code: #{language} - #{file_path}")

    case language do
      "elixir" -> analyze_elixir_code(code, file_path)
      "erlang" -> analyze_erlang_code(code, file_path)
      "gleam" -> analyze_gleam_code(code, file_path)
    end
  end

  def analyze_beam_code(language, _code, _file_path) do
    {:error,
     "Unsupported BEAM language: #{language}. Supported: #{Enum.join(@supported_beam_languages, ", ")}"}
  end

  @doc """
  Get supported BEAM languages.
  """
  def supported_beam_languages, do: @supported_beam_languages

  @doc """
  Check if a language is a BEAM language.
  """
  def beam_language?(language), do: language in @supported_beam_languages

  # Private functions

  defp analyze_elixir_code(code, file_path) do
    try do
      # Parse the code using tree-sitter
      {:ok, ast} = parse_elixir_code(code)

      # Perform comprehensive BEAM analysis
      case analyze_elixir_beam_patterns(ast, code, file_path) do
        {:error, reason} ->
          # CodeEngine failed - return error instead of continuing with degraded analysis
          {:error, "BEAM analysis failed: #{reason}"}

        beam_analysis ->
          # Extract language-specific features
          elixir_features = extract_elixir_features(ast, code, file_path)

          # Combine results
          analysis_result = %{
            language: "elixir",
            file_path: file_path,
            otp_patterns: beam_analysis.otp_patterns,
            actor_analysis: beam_analysis.actor_analysis,
            fault_tolerance: beam_analysis.fault_tolerance,
            beam_metrics: beam_analysis.beam_metrics,
            language_features: %{
              elixir: elixir_features,
              erlang: nil,
              gleam: nil
            },
            analysis_timestamp: DateTime.utc_now()
          }

          {:ok, analysis_result}
      end
    rescue
      error ->
        Logger.error("Failed to analyze Elixir code: #{inspect(error)}")
        {:error, "Elixir analysis failed: #{Exception.message(error)}"}
    end
  end

  defp analyze_erlang_code(code, file_path) do
    try do
      # Parse the code using tree-sitter
      {:ok, ast} = parse_erlang_code(code)

      # Perform comprehensive BEAM analysis
      case analyze_erlang_beam_patterns(ast, code, file_path) do
        {:error, reason} ->
          # CodeEngine failed - return error instead of continuing with degraded analysis
          {:error, "BEAM analysis failed: #{reason}"}

        beam_analysis ->
          # Extract language-specific features
          erlang_features = extract_erlang_features(ast, code, file_path)

          # Combine results
          analysis_result = %{
            language: "erlang",
            file_path: file_path,
            otp_patterns: beam_analysis.otp_patterns,
            actor_analysis: beam_analysis.actor_analysis,
            fault_tolerance: beam_analysis.fault_tolerance,
            beam_metrics: beam_analysis.beam_metrics,
            language_features: %{
              elixir: nil,
              erlang: erlang_features,
              gleam: nil
            },
            analysis_timestamp: DateTime.utc_now()
          }

          {:ok, analysis_result}
      end
    rescue
      error ->
        Logger.error("Failed to analyze Erlang code: #{inspect(error)}")
        {:error, "Erlang analysis failed: #{Exception.message(error)}"}
    end
  end

  defp analyze_gleam_code(code, file_path) do
    try do
      # Parse the code using tree-sitter
      {:ok, ast} = parse_gleam_code(code)

      # Perform comprehensive BEAM analysis
      beam_analysis = analyze_gleam_beam_patterns(ast, code, file_path)

      # Extract language-specific features
      gleam_features = extract_gleam_features(ast, code, file_path)

      # Combine results
      analysis_result = %{
        language: "gleam",
        file_path: file_path,
        otp_patterns: beam_analysis.otp_patterns,
        actor_analysis: beam_analysis.actor_analysis,
        fault_tolerance: beam_analysis.fault_tolerance,
        beam_metrics: beam_analysis.beam_metrics,
        language_features: %{
          elixir: nil,
          erlang: nil,
          gleam: gleam_features
        },
        analysis_timestamp: DateTime.utc_now()
      }

      {:ok, analysis_result}
    rescue
      error ->
        Logger.error("Failed to analyze Gleam code: #{inspect(error)}")
        {:error, "Gleam analysis failed: #{Exception.message(error)}"}
    end
  end

  # Elixir-specific analysis

  defp parse_elixir_code(code) do
    # Use CodeEngine for tree-sitter parsing
    case Singularity.CodeEngine.analyze_code(code, "elixir") do
      {:ok, analysis} ->
        # Extract AST from analysis result
        {:ok, analysis.ast || %{}}

      {:error, reason} ->
        {:error, "CodeEngine failed for Elixir parsing: #{inspect(reason)}"}
    end
  end

  defp analyze_elixir_beam_patterns(ast, code, file_path) do
    Logger.debug("BeamAnalysisEngine: Analyzing Elixir BEAM patterns for #{file_path}")

    # Use CodeEngine for comprehensive BEAM analysis
    case CodeEngine.analyze_language("elixir", code) do
      {:ok, analysis} ->
        # Record successful analysis
        # TODO: track timing
        CodeEngineHealthTracker.record_success("elixir", file_path, 0)

        # Extract OTP patterns from CodeEngine analysis
        otp_patterns = extract_otp_patterns_from_analysis(analysis, "elixir")
        actor_analysis = extract_actor_analysis_from_analysis(analysis, "elixir")
        fault_tolerance = extract_fault_tolerance_from_analysis(analysis, "elixir")
        beam_metrics = calculate_beam_metrics_from_analysis(analysis, code)

        # Enhance with AST-based analysis for additional patterns
        ast_patterns = extract_beam_patterns_from_ast(ast)

        %{
          otp_patterns: otp_patterns,
          actor_analysis: actor_analysis,
          fault_tolerance: fault_tolerance,
          beam_metrics: beam_metrics,
          ast_patterns: ast_patterns
        }

      {:error, reason} ->
        Logger.error("🚨 CodeEngine analysis FAILED for #{file_path}: #{inspect(reason)}")
        Logger.error("💥 FALLBACK - Using AST analysis for BEAM patterns")
        CodeEngineHealthTracker.record_fallback("elixir", file_path, reason)

        # Fallback to AST-based analysis
        ast_patterns = extract_beam_patterns_from_ast(ast)

        %{
          otp_patterns: [],
          actor_analysis: %{},
          fault_tolerance: %{},
          beam_metrics: %{},
          ast_patterns: ast_patterns
        }
    end
  end

  defp extract_elixir_features(_ast, code, file_path) do
    Logger.debug("BeamAnalysisEngine: Extracting Elixir features from #{file_path}")

    # Basic code analysis
    lines_of_code = code |> String.split("\n") |> length()
    has_use_macro = String.contains?(code, "use ")
    has_import_macro = String.contains?(code, "import ")
    has_alias_macro = String.contains?(code, "alias ")

    Logger.debug(
      "BeamAnalysisEngine: #{lines_of_code} lines, use: #{has_use_macro}, import: #{has_import_macro}, alias: #{has_alias_macro}"
    )

    # TODO: Use CodeEngine for comprehensive feature extraction
    # Current: Mock features with basic analysis
    # Target: CodeEngine.extract_functions("elixir", ast) + extract_imports_exports("elixir", ast)
    %{
      phoenix_usage: %{
        controllers: [],
        views: [],
        templates: [],
        channels: [],
        live_views: []
      },
      ecto_usage: %{
        schemas: [],
        migrations: [],
        queries: []
      },
      liveview_usage: %{
        live_views: [],
        live_components: []
      },
      nerves_usage: %{
        target: nil,
        system: nil,
        configs: []
      },
      broadway_usage: %{
        producers: [],
        processors: [],
        batchers: []
      }
    }
  end

  # Erlang-specific analysis

  defp parse_erlang_code(code) do
    # Use CodeEngine for tree-sitter parsing
    case Singularity.CodeEngine.analyze_code(code, "erlang") do
      {:ok, analysis} ->
        # Extract AST from analysis result
        {:ok, analysis.ast || %{}}

      {:error, reason} ->
        {:error, "CodeEngine failed for Erlang parsing: #{inspect(reason)}"}
    end
  end

  defp analyze_erlang_beam_patterns(_ast, code, file_path) do
    Logger.debug("BeamAnalysisEngine: Analyzing Erlang BEAM patterns for #{file_path}")

    # Use CodeEngine for comprehensive BEAM analysis
    case CodeEngine.analyze_language("erlang", code) do
      {:ok, analysis} ->
        # Record successful analysis
        CodeEngineHealthTracker.record_success("erlang", file_path, 0)

        # Extract OTP patterns from CodeEngine analysis
        otp_patterns = extract_otp_patterns_from_analysis(analysis, "erlang")
        actor_analysis = extract_actor_analysis_from_analysis(analysis, "erlang")
        fault_tolerance = extract_fault_tolerance_from_analysis(analysis, "erlang")
        beam_metrics = calculate_beam_metrics_from_analysis(analysis, code)

        %{
          otp_patterns: otp_patterns,
          actor_analysis: actor_analysis,
          fault_tolerance: fault_tolerance,
          beam_metrics: beam_metrics
        }

      {:error, reason} ->
        Logger.error("🚨 CodeEngine analysis FAILED for Erlang #{file_path}: #{inspect(reason)}")
        Logger.error("💥 NO FALLBACK - CodeEngine is required for BEAM analysis")
        CodeEngineHealthTracker.record_fallback("erlang", file_path, reason)

        # Report to SASL for proper error handling
        SASL.analysis_failure(
          :code_engine_failure,
          "CodeEngine analysis failed for Erlang file",
          language: "erlang",
          file_path: file_path,
          reason: reason
        )

        # Return error instead of degraded fallback
        {:error, "CodeEngine analysis failed for Erlang: #{inspect(reason)}"}
    end
  end

  defp extract_erlang_features(_ast, code, file_path) do
    Logger.debug("BeamAnalysisEngine: Analyzing Erlang BEAM patterns for #{file_path}")

    # Basic Erlang code analysis
    has_dash_include = String.contains?(code, "-include")
    has_dash_define = String.contains?(code, "-define")
    has_dash_behaviour = String.contains?(code, "-behaviour")

    Logger.debug(
      "BeamAnalysisEngine: Erlang file analysis - include: #{has_dash_include}, define: #{has_dash_define}, behaviour: #{has_dash_behaviour}"
    )

    # TODO: Use CodeEngine for comprehensive feature extraction
    # Current: Mock features with basic analysis
    # Target: CodeEngine.extract_functions("erlang", ast) + extract_imports_exports("erlang", ast)
    %{
      otp_behaviors: [],
      common_test_usage: %{
        test_suites: [],
        test_cases: []
      },
      dialyzer_usage: %{
        type_specs: [],
        contracts: []
      }
    }
  end

  # Gleam-specific analysis

  defp parse_gleam_code(code) do
    # Use CodeEngine for tree-sitter parsing
    case Singularity.CodeEngine.analyze_code(code, "gleam") do
      {:ok, analysis} ->
        # Extract AST from analysis result
        {:ok, analysis.ast || %{}}

      {:error, reason} ->
        {:error, "CodeEngine failed for Gleam parsing: #{inspect(reason)}"}
    end
  end

  defp analyze_gleam_beam_patterns(ast, code, file_path) do
    Logger.debug("BeamAnalysisEngine: Analyzing Gleam BEAM patterns for #{file_path}")

    # Basic AST size analysis
    ast_size = if is_map(ast), do: map_size(ast), else: 0
    code_length = String.length(code)

    Logger.debug("BeamAnalysisEngine: AST size: #{ast_size}, code length: #{code_length}")

    # TODO: Use CodeEngine for comprehensive BEAM analysis
    # Current: Regex-based pattern detection with mock metrics
    # Target: CodeEngine.analyze_language("gleam", code) + AST-based OTP pattern detection
    %{
      otp_patterns: %{
        genservers: detect_gleam_genservers(code),
        supervisors: detect_gleam_supervisors(code),
        applications: detect_gleam_applications(code),
        genevents: [],
        genstages: [],
        dynamic_supervisors: []
      },
      actor_analysis: %{
        process_spawning: %{
          spawn_calls: [],
          spawn_link_calls: [],
          task_async_calls: [],
          process_flags: [],
          process_registrations: []
        },
        message_passing: %{
          send_calls: [],
          receive_expressions: [],
          message_patterns: [],
          mailbox_analysis: %{
            estimated_queue_size: 0,
            processing_patterns: [],
            bottlenecks: []
          }
        },
        concurrency_patterns: %{
          agents: [],
          ets_tables: [],
          mnesia_usage: [],
          port_usage: []
        }
      },
      fault_tolerance: %{
        try_catch_expressions: [],
        rescue_clauses: [],
        let_it_crash_patterns: [],
        supervision_tree_depth: 0,
        error_handling_strategies: []
      },
      beam_metrics: %{
        estimated_process_count: 0,
        estimated_message_queue_size: 0,
        estimated_memory_usage: 0,
        gc_pressure: 0.0,
        supervision_complexity: 0.0,
        actor_complexity: 0.0,
        fault_tolerance_score: 0.0
      }
    }
  end

  defp extract_gleam_features(_ast, code, file_path) do
    Logger.debug("BeamAnalysisEngine: Extracting Gleam features from #{file_path}")

    # Basic Gleam code analysis
    lines_of_code = code |> String.split("\n") |> length()
    has_import = String.contains?(code, "import ")
    has_pub = String.contains?(code, "pub ")
    has_type = String.contains?(code, "type ")

    Logger.debug(
      "BeamAnalysisEngine: #{lines_of_code} lines, imports: #{has_import}, pub: #{has_pub}, types: #{has_type}"
    )

    # TODO: Use CodeEngine for comprehensive feature extraction
    # Current: Mock features with basic analysis
    # Target: CodeEngine.extract_functions("gleam", ast) + extract_imports_exports("gleam", ast)
    %{
      type_analysis: %{
        custom_types: [],
        type_aliases: [],
        type_features: %{}
      },
      functional_analysis: %{
        immutability_score: 100.0,
        pattern_match_complexity: 0.0,
        functional_features: %{}
      },
      beam_integration: %{
        interop_patterns: [],
        otp_usage: []
      },
      modern_features: %{
        language_features: %{}
      },
      web_patterns: %{
        http_patterns: [],
        web_safety_features: []
      }
    }
  end

  # Helper functions for CodeEngine analysis extraction

  defp extract_otp_patterns_from_analysis(analysis, language) do
    # Extract OTP patterns from CodeEngine analysis
    functions = analysis.functions || []
    modules = analysis.modules || []

    %{
      genservers: find_otp_behaviors(functions, modules, "GenServer", language),
      supervisors: find_otp_behaviors(functions, modules, "Supervisor", language),
      applications: find_otp_behaviors(functions, modules, "Application", language),
      genevents: find_otp_behaviors(functions, modules, "GenEvent", language),
      genstages: find_otp_behaviors(functions, modules, "GenStage", language),
      dynamic_supervisors: find_dynamic_supervisors(functions, language)
    }
  end

  defp extract_actor_analysis_from_analysis(analysis, language) do
    functions = analysis.functions || []
    calls = analysis.function_calls || []

    %{
      process_spawning: %{
        spawn_calls: find_function_calls(calls, ["spawn", "spawn_link", "spawn_monitor"]),
        spawn_link_calls: find_function_calls(calls, ["spawn_link"]),
        task_async_calls:
          find_function_calls(calls, ["Task.async", "Task.start", "Task.start_link"]),
        process_flags: extract_process_flags(functions),
        process_registrations: find_process_registrations(functions)
      },
      message_passing: %{
        send_calls: find_function_calls(calls, ["send", "GenServer.cast", "GenServer.call"]),
        receive_expressions: find_receive_expressions(analysis),
        message_patterns: extract_message_patterns(analysis),
        mailbox_analysis: calculate_mailbox_analysis(analysis)
      },
      concurrency_patterns: %{
        agents: find_otp_behaviors(functions, [], "Agent", language),
        ets_tables: find_ets_usage(functions, calls),
        mnesia_usage: find_mnesia_usage(functions, calls),
        port_usage: find_port_usage(functions, calls)
      }
    }
  end

  defp extract_fault_tolerance_from_analysis(analysis, _language) do
    functions = analysis.functions || []

    %{
      try_catch_expressions: find_try_catch_blocks(analysis),
      rescue_clauses: find_rescue_clauses(analysis),
      let_it_crash_patterns: find_let_it_crash_patterns(functions),
      supervision_tree_depth: calculate_supervision_depth(analysis),
      error_handling_strategies: identify_error_strategies(functions)
    }
  end

  defp calculate_beam_metrics_from_analysis(analysis, code) do
    functions = analysis.functions || []
    modules = analysis.modules || []

    analysis_metrics = %{
      estimated_process_count: estimate_process_count(functions),
      estimated_message_queue_size: estimate_message_queue_size(functions),
      estimated_memory_usage: estimate_memory_usage(functions, modules),
      gc_pressure: calculate_gc_pressure(analysis),
      supervision_complexity: calculate_supervision_complexity(modules),
      actor_complexity: calculate_actor_complexity(functions),
      fault_tolerance_score: calculate_fault_tolerance_score(analysis)
    }

    heuristics = basic_beam_metrics_from_code(code)

    Map.merge(heuristics, analysis_metrics, fn _key, heuristic_value, analysis_value ->
      cond do
        is_nil(analysis_value) -> heuristic_value
        is_number(analysis_value) and analysis_value == 0 -> heuristic_value
        analysis_value == %{} -> heuristic_value
        true -> analysis_value
      end
    end)
  end

  # Specific extraction functions

  defp find_otp_behaviors(functions, modules, behavior_name, _language) do
    # Look for modules that use the specified OTP behavior
    modules_using_behavior =
      Enum.filter(modules, fn module ->
        behaviors = module.behaviors || []
        Enum.any?(behaviors, &String.contains?(&1, behavior_name))
      end)

    Enum.map(modules_using_behavior, fn module ->
      %{
        name: module.name,
        module: module.name,
        line_start: module.line_start || 0,
        line_end: module.line_end || 0,
        callbacks: extract_callbacks_for_behavior(functions, module.name, behavior_name),
        state_type: extract_state_type(functions, module.name),
        message_types: extract_message_types(functions, module.name)
      }
    end)
  end

  defp find_function_calls(calls, target_functions) do
    Enum.filter(calls, fn call ->
      function_name = call.function_name || ""
      Enum.any?(target_functions, &String.contains?(function_name, &1))
    end)
  end

  # Heuristic helpers --------------------------------------------------------

  defp basic_beam_metrics_from_code(code) do
    lines = String.split(code, "\n")

    spawn_occurrences = line_occurrences(lines, ~r/\bspawn(?:_(?:link|monitor))?\b/i)
    task_occurrences = line_occurrences(lines, ~r/\bTask\.(?:async|start(?:_link)?)\b/)
    send_occurrences = line_occurrences(lines, ~r/(!|\bGenServer\.(?:cast|call)\b)/)
    supervisor_occurrences = line_occurrences(lines, ~r/\bSupervisor\b/)
    try_occurrences = line_occurrences(lines, ~r/\btry\b/)

    total_process_points = length(spawn_occurrences) + length(task_occurrences)
    total_send_points = length(send_occurrences)
    loc = max(length(lines), 1)

    %{
      estimated_process_count: total_process_points + 1,
      estimated_message_queue_size: total_send_points * 5,
      estimated_memory_usage: loc * 80,
      gc_pressure: Float.round(min(total_process_points * 0.05, 1.0), 2),
      supervision_complexity: Float.round(min(length(supervisor_occurrences) * 0.2, 5.0), 2),
      actor_complexity:
        Float.round(min((total_process_points + total_send_points) * 0.1, 5.0), 2),
      fault_tolerance_score:
        Float.round(
          min(length(try_occurrences) * 0.15 + length(supervisor_occurrences) * 0.2, 10.0),
          2
        )
    }
  end

  defp basic_actor_analysis_from_code(code) do
    lines = String.split(code, "\n")

    spawn_calls = line_occurrences(lines, ~r/\bspawn\b/)
    spawn_link_calls = line_occurrences(lines, ~r/\bspawn_link\b/)
    task_calls = line_occurrences(lines, ~r/\bTask\.(?:async|start(?:_link)?)\b/)
    send_calls = line_occurrences(lines, ~r/(!|\bGenServer\.(?:cast|call)\b)/)
    receive_blocks = line_occurrences(lines, ~r/\breceive\b/)
    agent_usage = line_occurrences(lines, ~r/\bAgent\./)
    ets_usage = line_occurrences(lines, ~r/\b:ets\./)
    mnesia_usage = line_occurrences(lines, ~r/\b:mnesia\./)
    port_usage = line_occurrences(lines, ~r/\bPort\./)

    %{
      process_spawning: %{
        spawn_calls: spawn_calls,
        spawn_link_calls: spawn_link_calls,
        task_async_calls: task_calls,
        process_flags: [],
        process_registrations: []
      },
      message_passing: %{
        send_calls: send_calls,
        receive_expressions: receive_blocks,
        message_patterns: [],
        mailbox_analysis: %{
          estimated_queue_size: max(length(send_calls) - length(receive_blocks), 0),
          processing_patterns: [],
          bottlenecks: []
        }
      },
      concurrency_patterns: %{
        agents: agent_usage,
        ets_tables: ets_usage,
        mnesia_usage: mnesia_usage,
        port_usage: port_usage
      }
    }
  end

  defp basic_fault_tolerance_from_code(code) do
    lines = String.split(code, "\n")

    try_blocks = line_occurrences(lines, ~r/\btry\b/)
    rescue_clauses = line_occurrences(lines, ~r/\brescue\b/)
    catch_clauses = line_occurrences(lines, ~r/\bcatch\b/)
    let_it_crash = line_occurrences(lines, ~r/\braise\b|\bexit\b/)

    %{
      try_catch_expressions: try_blocks ++ catch_clauses,
      rescue_clauses: rescue_clauses,
      let_it_crash_patterns: let_it_crash,
      supervision_tree_depth: length(try_blocks),
      error_handling_strategies:
        Enum.map(rescue_clauses, fn occ -> %{line: occ.line, strategy: :rescue} end)
    }
  end

  defp line_occurrences(lines, regex) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_no}, acc ->
      if Regex.match?(regex, line) do
        snippet = line |> String.trim() |> String.slice(0, 120)
        [%{line: line_no, snippet: snippet} | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  # Fallback analysis for when CodeEngine fails
  defp fallback_elixir_analysis(code) do
    %{
      otp_patterns: %{
        genservers: detect_elixir_genservers(code),
        supervisors: detect_elixir_supervisors(code),
        applications: detect_elixir_applications(code),
        genevents: [],
        genstages: [],
        dynamic_supervisors: []
      },
      actor_analysis: basic_actor_analysis_from_code(code),
      fault_tolerance: basic_fault_tolerance_from_code(code),
      beam_metrics: basic_beam_metrics_from_code(code)
    }
  end

  # Fallback analysis for when CodeEngine fails for Erlang
  defp fallback_erlang_analysis(code) do
    %{
      otp_patterns: %{
        genservers: detect_erlang_gen_servers(code),
        supervisors: detect_erlang_supervisors(code),
        applications: detect_erlang_applications(code),
        genevents: [],
        genstages: [],
        dynamic_supervisors: []
      },
      actor_analysis: basic_actor_analysis_from_code(code),
      fault_tolerance: basic_fault_tolerance_from_code(code),
      beam_metrics: basic_beam_metrics_from_code(code)
    }
  end

  defp detect_elixir_genservers(code) do
    # Detect "use GenServer" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "use GenServer") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "GenServer_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        callbacks: [
          "init/1",
          "handle_call/3",
          "handle_cast/2",
          "handle_info/2",
          "terminate/2",
          "code_change/3"
        ],
        state_type: nil,
        message_types: []
      }
    end)
  end

  defp detect_elixir_supervisors(code) do
    # Detect "use Supervisor" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "use Supervisor") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "Supervisor_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        strategy: ":one_for_one",
        children: []
      }
    end)
  end

  defp detect_elixir_applications(code) do
    # Detect "use Application" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "use Application") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "Application_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        mod: nil,
        start_phases: [],
        applications: []
      }
    end)
  end

  defp detect_erlang_gen_servers(code) do
    # Detect "-behaviour(gen_server)" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "-behaviour(gen_server)") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "GenServer_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        callbacks: [
          "init/1",
          "handle_call/3",
          "handle_cast/2",
          "handle_info/2",
          "terminate/2",
          "code_change/3"
        ],
        state_type: nil,
        message_types: []
      }
    end)
  end

  defp detect_erlang_supervisors(code) do
    # Detect "-behaviour(supervisor)" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "-behaviour(supervisor)") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "Supervisor_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        strategy: "one_for_one",
        children: []
      }
    end)
  end

  defp detect_erlang_applications(code) do
    # Detect "-behaviour(application)" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "-behaviour(application)") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "Application_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        mod: nil,
        start_phases: [],
        applications: []
      }
    end)
  end

  defp detect_gleam_genservers(code) do
    # Detect "import gleam_otp" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "import gleam_otp") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "GenServer_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        callbacks: [
          "init/1",
          "handle_call/3",
          "handle_cast/2",
          "handle_info/2",
          "terminate/2",
          "code_change/3"
        ],
        state_type: nil,
        message_types: []
      }
    end)
  end

  defp detect_gleam_supervisors(code) do
    # Detect "import gleam_otp" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "import gleam_otp") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "Supervisor_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        strategy: "one_for_one",
        children: []
      }
    end)
  end

  defp detect_gleam_applications(code) do
    # Detect "import gleam_otp" patterns
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "import gleam_otp") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        name: "Application_#{line_num}",
        module: extract_module_name(line),
        line_start: line_num,
        line_end: line_num,
        mod: nil,
        start_phases: [],
        applications: []
      }
    end)
  end

  defp extract_module_name(line) do
    # Extract module name from various patterns
    cond do
      String.contains?(line, "use ") ->
        line
        |> String.split("use ")
        |> List.last()
        |> String.trim()
        |> String.split(" ")
        |> List.first()
        |> String.trim()

      String.contains?(line, "-behaviour(") ->
        line
        |> String.split("-behaviour(")
        |> List.last()
        |> String.split(")")
        |> List.first()
        |> String.trim()

      String.contains?(line, "import ") ->
        line
        |> String.split("import ")
        |> List.last()
        |> String.trim()

      true ->
        "Unknown"
    end
  end

  # Stub implementations for CodeEngine analysis extraction functions
  # These will be replaced with actual implementations when CodeEngine provides structured data

  defp estimate_process_count(_functions), do: 0
  defp estimate_message_queue_size(_functions), do: 0
  defp estimate_memory_usage(_functions, _modules), do: 0
  defp calculate_gc_pressure(_analysis), do: 0.0
  defp calculate_supervision_complexity(_modules), do: 0.0
  defp calculate_actor_complexity(_functions), do: 0.0
  defp calculate_fault_tolerance_score(_analysis), do: 0.0

  defp find_try_catch_blocks(_analysis), do: []
  defp find_rescue_clauses(_analysis), do: []
  defp find_let_it_crash_patterns(_functions), do: []
  defp calculate_supervision_depth(_analysis), do: 0
  defp identify_error_strategies(_functions), do: []

  defp extract_process_flags(_functions), do: []
  defp find_process_registrations(_functions), do: []
  defp find_receive_expressions(_analysis), do: []
  defp extract_message_patterns(_analysis), do: []

  defp calculate_mailbox_analysis(_analysis),
    do: %{estimated_queue_size: 0, processing_patterns: [], bottlenecks: []}

  defp find_ets_usage(_functions, _calls), do: []
  defp find_mnesia_usage(_functions, _calls), do: []

  # AST-based BEAM pattern extraction for fallback analysis
  defp extract_beam_patterns_from_ast(ast) do
    %{
      modules: extract_module_calls(ast),
      processes: extract_process_operations(ast),
      supervisors: extract_supervisor_patterns(ast),
      gen_servers: extract_gen_server_patterns(ast),
      messages: extract_message_passing(ast)
    }
  end

  defp extract_module_calls({:defmodule, _, [{:__aliases__, _, module_name}, [do: body]]}) do
    [%{name: module_name, type: :module, body: body}]
  end

  defp extract_module_calls({:defmodule, _, _}), do: []
  defp extract_module_calls(ast) when is_list(ast) do
    Enum.flat_map(ast, &extract_module_calls/1)
  end

  defp extract_module_calls(_), do: []

  defp extract_process_operations(ast) do
    # Look for spawn, send, receive patterns
    find_processes_in_ast(ast, [])
  end

  defp extract_supervisor_patterns(ast) do
    # Look for Supervisor.start_link, child specs
    find_supervisors_in_ast(ast, [])
  end

  defp extract_gen_server_patterns(ast) do
    # Look for GenServer callbacks and calls
    find_gen_servers_in_ast(ast, [])
  end

  defp extract_message_passing(ast) do
    # Look for send/2, receive blocks
    find_messages_in_ast(ast, [])
  end

  # Helper functions for AST traversal
  defp find_processes_in_ast({:spawn, _, _} = node, acc), do: [node | acc]
  defp find_processes_in_ast({:send, _, _} = node, acc), do: [node | acc]
  defp find_processes_in_ast({:receive, _, _} = node, acc), do: [node | acc]
  defp find_processes_in_ast(ast, acc) when is_list(ast) do
    Enum.flat_map(ast, &find_processes_in_ast(&1, [])) ++ acc
  end
  defp find_processes_in_ast(ast, acc) when is_tuple(ast) and tuple_size(ast) == 3 do
    find_processes_in_ast(elem(ast, 2), acc)
  end
  defp find_processes_in_ast(_, acc), do: acc

  defp find_supervisors_in_ast({{:., _, [{:__aliases__, _, [:Supervisor]}, :start_link]}, _, _} = node, acc), do: [node | acc]
  defp find_supervisors_in_ast(ast, acc) when is_list(ast) do
    Enum.flat_map(ast, &find_supervisors_in_ast(&1, [])) ++ acc
  end
  defp find_supervisors_in_ast(ast, acc) when is_tuple(ast) and tuple_size(ast) == 3 do
    find_supervisors_in_ast(elem(ast, 2), acc)
  end
  defp find_supervisors_in_ast(_, acc), do: acc

  defp find_gen_servers_in_ast({:def, _, [{:handle_call, _, _}, _]} = node, acc), do: [node | acc]
  defp find_gen_servers_in_ast({:def, _, [{:handle_cast, _, _}, _]} = node, acc), do: [node | acc]
  defp find_gen_servers_in_ast({:def, _, [{:handle_info, _, _}, _]} = node, acc), do: [node | acc]
  defp find_gen_servers_in_ast({{:., _, [{:__aliases__, _, [:GenServer]}, _]}, _, _} = node, acc), do: [node | acc]
  defp find_gen_servers_in_ast(ast, acc) when is_list(ast) do
    Enum.flat_map(ast, &find_gen_servers_in_ast(&1, [])) ++ acc
  end
  defp find_gen_servers_in_ast(ast, acc) when is_tuple(ast) and tuple_size(ast) == 3 do
    find_gen_servers_in_ast(elem(ast, 2), acc)
  end
  defp find_gen_servers_in_ast(_, acc), do: acc

  defp find_messages_in_ast({:send, _, _} = node, acc), do: [node | acc]
  defp find_messages_in_ast({:receive, _, _} = node, acc), do: [node | acc]
  defp find_messages_in_ast(ast, acc) when is_list(ast) do
    Enum.flat_map(ast, &find_messages_in_ast(&1, [])) ++ acc
  end
  defp find_messages_in_ast(ast, acc) when is_tuple(ast) and tuple_size(ast) == 3 do
    find_messages_in_ast(elem(ast, 2), acc)
  end
  defp find_messages_in_ast(_, acc), do: acc
  defp find_port_usage(_functions, _calls), do: []

  defp find_dynamic_supervisors(_functions, _language), do: []

  defp extract_callbacks_for_behavior(_functions, _module_name, _behavior_name), do: []
  defp extract_state_type(_functions, _module_name), do: nil
  defp extract_message_types(_functions, _module_name), do: []
end
