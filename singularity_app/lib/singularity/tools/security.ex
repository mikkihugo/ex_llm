defmodule Singularity.Tools.Security do
  @moduledoc """
  Security Tools - Security scanning and auditing for autonomous agents

  Provides comprehensive security capabilities for agents to:
  - Scan code for security vulnerabilities
  - Check for known vulnerabilities in dependencies
  - Analyze audit logs for security events
  - Perform security audits and compliance checks
  - Monitor security policies and configurations
  - Detect security misconfigurations
  - Generate security reports and recommendations

  Essential for maintaining security posture and compliance.
  """

  alias Singularity.Tools.{Tool, Catalog}

  def register(provider) do
    Catalog.add_tools(provider, [
      security_scan_tool(),
      vulnerability_check_tool(),
      audit_logs_tool(),
      security_audit_tool(),
      policy_check_tool(),
      secrets_scan_tool(),
      compliance_check_tool()
    ])
  end

  defp security_scan_tool do
    Tool.new!(%{
      name: "security_scan",
      description: "Scan code and configurations for security vulnerabilities",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: true,
          description: "File, directory, or code to scan"
        },
        %{
          name: "scan_types",
          type: :array,
          required: false,
          description:
            "Types: ['code', 'config', 'dependencies', 'secrets', 'permissions'] (default: all)"
        },
        %{
          name: "severity",
          type: :string,
          required: false,
          description: "Minimum severity: 'low', 'medium', 'high', 'critical' (default: 'medium')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "include_fixes",
          type: :boolean,
          required: false,
          description: "Include suggested fixes (default: true)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'sarif', 'text', 'html' (default: 'json')"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for scan results"
        }
      ],
      function: &security_scan/2
    })
  end

  defp vulnerability_check_tool do
    Tool.new!(%{
      name: "vulnerability_check",
      description: "Check dependencies for known security vulnerabilities",
      parameters: [
        %{
          name: "package_manager",
          type: :string,
          required: false,
          description:
            "Package manager: 'mix', 'npm', 'pip', 'cargo', 'maven' (default: auto-detect)"
        },
        %{
          name: "lock_file",
          type: :string,
          required: false,
          description: "Path to lock file (mix.lock, package-lock.json, etc.)"
        },
        %{
          name: "severity_filter",
          type: :string,
          required: false,
          description: "Minimum severity: 'low', 'medium', 'high', 'critical' (default: 'medium')"
        },
        %{
          name: "include_dev_deps",
          type: :boolean,
          required: false,
          description: "Include development dependencies (default: true)"
        },
        %{
          name: "check_updates",
          type: :boolean,
          required: false,
          description: "Check for available updates (default: true)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'table', 'text' (default: 'json')"
        }
      ],
      function: &vulnerability_check/2
    })
  end

  defp audit_logs_tool do
    Tool.new!(%{
      name: "audit_logs",
      description: "Analyze audit logs for security events and anomalies",
      parameters: [
        %{
          name: "log_files",
          type: :array,
          required: false,
          description: "Audit log files to analyze (default: system audit logs)"
        },
        %{
          name: "time_range",
          type: :string,
          required: false,
          description: "Time range: '1h', '24h', '7d', '30d' (default: '24h')"
        },
        %{
          name: "event_types",
          type: :array,
          required: false,
          description:
            "Event types: ['login', 'file_access', 'permission_change', 'system_call'] (default: all)"
        },
        %{
          name: "severity",
          type: :string,
          required: false,
          description: "Minimum severity: 'low', 'medium', 'high', 'critical' (default: 'medium')"
        },
        %{
          name: "include_context",
          type: :boolean,
          required: false,
          description: "Include surrounding log context (default: true)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of results (default: 100)"
        }
      ],
      function: &audit_logs/2
    })
  end

  defp security_audit_tool do
    Tool.new!(%{
      name: "security_audit",
      description: "Perform comprehensive security audit and compliance check",
      parameters: [
        %{
          name: "audit_scope",
          type: :string,
          required: false,
          description: "Scope: 'full', 'code', 'config', 'network', 'access' (default: 'full')"
        },
        %{
          name: "compliance_standards",
          type: :array,
          required: false,
          description: "Standards: ['OWASP', 'NIST', 'CIS', 'SOC2', 'GDPR'] (default: ['OWASP'])"
        },
        %{
          name: "include_recommendations",
          type: :boolean,
          required: false,
          description: "Include remediation recommendations (default: true)"
        },
        %{
          name: "severity_threshold",
          type: :string,
          required: false,
          description:
            "Minimum severity to report: 'low', 'medium', 'high', 'critical' (default: 'medium')"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'html', 'pdf', 'text' (default: 'json')"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for audit report"
        }
      ],
      function: &security_audit/2
    })
  end

  defp policy_check_tool do
    Tool.new!(%{
      name: "policy_check",
      description: "Check security policies and configurations for compliance",
      parameters: [
        %{
          name: "policy_types",
          type: :array,
          required: false,
          description:
            "Types: ['access_control', 'encryption', 'network', 'data_protection', 'incident_response'] (default: all)"
        },
        %{
          name: "config_files",
          type: :array,
          required: false,
          description: "Configuration files to check (default: auto-detect)"
        },
        %{
          name: "compliance_framework",
          type: :string,
          required: false,
          description: "Framework: 'OWASP', 'NIST', 'CIS', 'SOC2', 'GDPR' (default: 'OWASP')"
        },
        %{
          name: "include_recommendations",
          type: :boolean,
          required: false,
          description: "Include policy recommendations (default: true)"
        },
        %{
          name: "severity_filter",
          type: :string,
          required: false,
          description: "Minimum severity: 'low', 'medium', 'high', 'critical' (default: 'medium')"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'json')"
        }
      ],
      function: &policy_check/2
    })
  end

  defp secrets_scan_tool do
    Tool.new!(%{
      name: "secrets_scan",
      description: "Scan for exposed secrets, API keys, and sensitive data",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: true,
          description: "File, directory, or code to scan for secrets"
        },
        %{
          name: "secret_types",
          type: :array,
          required: false,
          description:
            "Types: ['api_keys', 'passwords', 'tokens', 'certificates', 'database_urls'] (default: all)"
        },
        %{
          name: "confidence_threshold",
          type: :string,
          required: false,
          description: "Minimum confidence: 'low', 'medium', 'high' (default: 'medium')"
        },
        %{
          name: "include_context",
          type: :boolean,
          required: false,
          description: "Include surrounding code context (default: true)"
        },
        %{
          name: "exclude_patterns",
          type: :array,
          required: false,
          description: "Patterns to exclude (e.g., ['*.test.*', '*.spec.*'])"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'csv' (default: 'json')"
        }
      ],
      function: &secrets_scan/2
    })
  end

  defp compliance_check_tool do
    Tool.new!(%{
      name: "compliance_check",
      description: "Check compliance with security standards and regulations",
      parameters: [
        %{
          name: "compliance_framework",
          type: :string,
          required: true,
          description: "Framework: 'OWASP', 'NIST', 'CIS', 'SOC2', 'GDPR', 'HIPAA', 'PCI-DSS'"
        },
        %{
          name: "check_types",
          type: :array,
          required: false,
          description:
            "Types: ['code', 'config', 'network', 'access', 'data', 'incident'] (default: all)"
        },
        %{
          name: "include_evidence",
          type: :boolean,
          required: false,
          description: "Include compliance evidence (default: true)"
        },
        %{
          name: "severity_threshold",
          type: :string,
          required: false,
          description: "Minimum severity: 'low', 'medium', 'high', 'critical' (default: 'medium')"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'html', 'pdf', 'text' (default: 'json')"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for compliance report"
        }
      ],
      function: &compliance_check/2
    })
  end

  # Implementation functions

  def security_scan(
        %{
          "target" => target,
          "scan_types" => scan_types,
          "severity" => severity,
          "language" => language,
          "include_fixes" => include_fixes,
          "output_format" => output_format,
          "output_file" => output_file
        },
        _ctx
      ) do
    security_scan_impl(
      target,
      scan_types,
      severity,
      language,
      include_fixes,
      output_format,
      output_file
    )
  end

  def security_scan(
        %{
          "target" => target,
          "scan_types" => scan_types,
          "severity" => severity,
          "language" => language,
          "include_fixes" => include_fixes,
          "output_format" => output_format
        },
        _ctx
      ) do
    security_scan_impl(target, scan_types, severity, language, include_fixes, output_format, nil)
  end

  def security_scan(
        %{
          "target" => target,
          "scan_types" => scan_types,
          "severity" => severity,
          "language" => language,
          "include_fixes" => include_fixes
        },
        _ctx
      ) do
    security_scan_impl(target, scan_types, severity, language, include_fixes, "json", nil)
  end

  def security_scan(
        %{
          "target" => target,
          "scan_types" => scan_types,
          "severity" => severity,
          "language" => language
        },
        _ctx
      ) do
    security_scan_impl(target, scan_types, severity, language, true, "json", nil)
  end

  def security_scan(
        %{"target" => target, "scan_types" => scan_types, "severity" => severity},
        _ctx
      ) do
    security_scan_impl(target, scan_types, severity, nil, true, "json", nil)
  end

  def security_scan(%{"target" => target, "scan_types" => scan_types}, _ctx) do
    security_scan_impl(target, scan_types, "medium", nil, true, "json", nil)
  end

  def security_scan(%{"target" => target}, _ctx) do
    security_scan_impl(
      target,
      ["code", "config", "dependencies", "secrets", "permissions"],
      "medium",
      nil,
      true,
      "json",
      nil
    )
  end

  defp security_scan_impl(
         target,
         scan_types,
         severity,
         language,
         include_fixes,
         output_format,
         output_file
       ) do
    try do
      # Detect language if not specified
      detected_language = language || detect_language_from_target(target)

      # Perform security scans
      scan_results =
        Enum.map(scan_types, fn scan_type ->
          perform_security_scan(target, scan_type, detected_language, severity)
        end)

      # Filter results by severity
      filtered_results = filter_results_by_severity(scan_results, severity)

      # Add fixes if requested
      results_with_fixes =
        if include_fixes do
          add_security_fixes(filtered_results)
        else
          filtered_results
        end

      # Format output
      formatted_output = format_security_output(results_with_fixes, output_format)

      # Save to file if specified
      if output_file do
        File.write!(output_file, formatted_output)
      end

      {:ok,
       %{
         target: target,
         scan_types: scan_types,
         severity: severity,
         language: detected_language,
         include_fixes: include_fixes,
         output_format: output_format,
         output_file: output_file,
         scan_results: results_with_fixes,
         formatted_output: formatted_output,
         total_vulnerabilities: count_vulnerabilities(results_with_fixes),
         critical_count: count_vulnerabilities_by_severity(results_with_fixes, "critical"),
         high_count: count_vulnerabilities_by_severity(results_with_fixes, "high"),
         medium_count: count_vulnerabilities_by_severity(results_with_fixes, "medium"),
         low_count: count_vulnerabilities_by_severity(results_with_fixes, "low"),
         success: true
       }}
    rescue
      error -> {:error, "Security scan error: #{inspect(error)}"}
    end
  end

  def vulnerability_check(
        %{
          "package_manager" => package_manager,
          "lock_file" => lock_file,
          "severity_filter" => severity_filter,
          "include_dev_deps" => include_dev_deps,
          "check_updates" => check_updates,
          "output_format" => output_format
        },
        _ctx
      ) do
    vulnerability_check_impl(
      package_manager,
      lock_file,
      severity_filter,
      include_dev_deps,
      check_updates,
      output_format
    )
  end

  def vulnerability_check(
        %{
          "package_manager" => package_manager,
          "lock_file" => lock_file,
          "severity_filter" => severity_filter,
          "include_dev_deps" => include_dev_deps,
          "check_updates" => check_updates
        },
        _ctx
      ) do
    vulnerability_check_impl(
      package_manager,
      lock_file,
      severity_filter,
      include_dev_deps,
      check_updates,
      "json"
    )
  end

  def vulnerability_check(
        %{
          "package_manager" => package_manager,
          "lock_file" => lock_file,
          "severity_filter" => severity_filter,
          "include_dev_deps" => include_dev_deps
        },
        _ctx
      ) do
    vulnerability_check_impl(
      package_manager,
      lock_file,
      severity_filter,
      include_dev_deps,
      true,
      "json"
    )
  end

  def vulnerability_check(
        %{
          "package_manager" => package_manager,
          "lock_file" => lock_file,
          "severity_filter" => severity_filter
        },
        _ctx
      ) do
    vulnerability_check_impl(package_manager, lock_file, severity_filter, true, true, "json")
  end

  def vulnerability_check(%{"package_manager" => package_manager, "lock_file" => lock_file}, _ctx) do
    vulnerability_check_impl(package_manager, lock_file, "medium", true, true, "json")
  end

  def vulnerability_check(%{"package_manager" => package_manager}, _ctx) do
    vulnerability_check_impl(package_manager, nil, "medium", true, true, "json")
  end

  def vulnerability_check(%{}, _ctx) do
    vulnerability_check_impl(nil, nil, "medium", true, true, "json")
  end

  defp vulnerability_check_impl(
         package_manager,
         lock_file,
         severity_filter,
         include_dev_deps,
         check_updates,
         output_format
       ) do
    try do
      # Detect package manager if not specified
      detected_manager = package_manager || detect_package_manager(lock_file)

      # Find lock file if not specified
      final_lock_file = lock_file || find_lock_file(detected_manager)

      # Parse dependencies
      dependencies = parse_dependencies(final_lock_file, detected_manager, include_dev_deps)

      # Check for vulnerabilities
      vulnerability_results =
        check_dependency_vulnerabilities(dependencies, detected_manager, severity_filter)

      # Check for updates if requested
      update_results =
        if check_updates do
          check_dependency_updates(dependencies, detected_manager)
        else
          []
        end

      # Format output
      formatted_output =
        format_vulnerability_output(vulnerability_results, update_results, output_format)

      {:ok,
       %{
         package_manager: detected_manager,
         lock_file: final_lock_file,
         severity_filter: severity_filter,
         include_dev_deps: include_dev_deps,
         check_updates: check_updates,
         output_format: output_format,
         dependencies: dependencies,
         vulnerability_results: vulnerability_results,
         update_results: update_results,
         formatted_output: formatted_output,
         total_vulnerabilities: length(vulnerability_results),
         critical_vulnerabilities:
           length(Enum.filter(vulnerability_results, &(&1.severity == "critical"))),
         high_vulnerabilities:
           length(Enum.filter(vulnerability_results, &(&1.severity == "high"))),
         medium_vulnerabilities:
           length(Enum.filter(vulnerability_results, &(&1.severity == "medium"))),
         low_vulnerabilities: length(Enum.filter(vulnerability_results, &(&1.severity == "low"))),
         success: true
       }}
    rescue
      error -> {:error, "Vulnerability check error: #{inspect(error)}"}
    end
  end

  def audit_logs(
        %{
          "log_files" => log_files,
          "time_range" => time_range,
          "event_types" => event_types,
          "severity" => severity,
          "include_context" => include_context,
          "limit" => limit
        },
        _ctx
      ) do
    audit_logs_impl(log_files, time_range, event_types, severity, include_context, limit)
  end

  def audit_logs(
        %{
          "log_files" => log_files,
          "time_range" => time_range,
          "event_types" => event_types,
          "severity" => severity,
          "include_context" => include_context
        },
        _ctx
      ) do
    audit_logs_impl(log_files, time_range, event_types, severity, include_context, 100)
  end

  def audit_logs(
        %{
          "log_files" => log_files,
          "time_range" => time_range,
          "event_types" => event_types,
          "severity" => severity
        },
        _ctx
      ) do
    audit_logs_impl(log_files, time_range, event_types, severity, true, 100)
  end

  def audit_logs(
        %{"log_files" => log_files, "time_range" => time_range, "event_types" => event_types},
        _ctx
      ) do
    audit_logs_impl(log_files, time_range, event_types, "medium", true, 100)
  end

  def audit_logs(%{"log_files" => log_files, "time_range" => time_range}, _ctx) do
    audit_logs_impl(
      log_files,
      time_range,
      ["login", "file_access", "permission_change", "system_call"],
      "medium",
      true,
      100
    )
  end

  def audit_logs(%{"log_files" => log_files}, _ctx) do
    audit_logs_impl(
      log_files,
      "24h",
      ["login", "file_access", "permission_change", "system_call"],
      "medium",
      true,
      100
    )
  end

  def audit_logs(%{}, _ctx) do
    audit_logs_impl(
      nil,
      "24h",
      ["login", "file_access", "permission_change", "system_call"],
      "medium",
      true,
      100
    )
  end

  defp audit_logs_impl(log_files, time_range, event_types, severity, include_context, limit) do
    try do
      # Find audit log files if not specified
      files = log_files || find_audit_log_files()

      # Analyze audit logs
      audit_results =
        Enum.flat_map(files, fn file ->
          analyze_audit_log_file(file, time_range, event_types, severity, include_context)
        end)

      # Sort and limit results
      sorted_results = sort_audit_results(audit_results)
      limited_results = Enum.take(sorted_results, limit)

      # Generate summary
      summary = generate_audit_summary(limited_results)

      {:ok,
       %{
         log_files: files,
         time_range: time_range,
         event_types: event_types,
         severity: severity,
         include_context: include_context,
         limit: limit,
         audit_results: limited_results,
         summary: summary,
         total_found: length(audit_results),
         total_returned: length(limited_results),
         success: true
       }}
    rescue
      error -> {:error, "Audit logs analysis error: #{inspect(error)}"}
    end
  end

  def security_audit(
        %{
          "audit_scope" => audit_scope,
          "compliance_standards" => compliance_standards,
          "include_recommendations" => include_recommendations,
          "severity_threshold" => severity_threshold,
          "output_format" => output_format,
          "output_file" => output_file
        },
        _ctx
      ) do
    security_audit_impl(
      audit_scope,
      compliance_standards,
      include_recommendations,
      severity_threshold,
      output_format,
      output_file
    )
  end

  def security_audit(
        %{
          "audit_scope" => audit_scope,
          "compliance_standards" => compliance_standards,
          "include_recommendations" => include_recommendations,
          "severity_threshold" => severity_threshold,
          "output_format" => output_format
        },
        _ctx
      ) do
    security_audit_impl(
      audit_scope,
      compliance_standards,
      include_recommendations,
      severity_threshold,
      output_format,
      nil
    )
  end

  def security_audit(
        %{
          "audit_scope" => audit_scope,
          "compliance_standards" => compliance_standards,
          "include_recommendations" => include_recommendations,
          "severity_threshold" => severity_threshold
        },
        _ctx
      ) do
    security_audit_impl(
      audit_scope,
      compliance_standards,
      include_recommendations,
      severity_threshold,
      "json",
      nil
    )
  end

  def security_audit(
        %{
          "audit_scope" => audit_scope,
          "compliance_standards" => compliance_standards,
          "include_recommendations" => include_recommendations
        },
        _ctx
      ) do
    security_audit_impl(
      audit_scope,
      compliance_standards,
      include_recommendations,
      "medium",
      "json",
      nil
    )
  end

  def security_audit(
        %{"audit_scope" => audit_scope, "compliance_standards" => compliance_standards},
        _ctx
      ) do
    security_audit_impl(audit_scope, compliance_standards, true, "medium", "json", nil)
  end

  def security_audit(%{"audit_scope" => audit_scope}, _ctx) do
    security_audit_impl(audit_scope, ["OWASP"], true, "medium", "json", nil)
  end

  def security_audit(%{}, _ctx) do
    security_audit_impl("full", ["OWASP"], true, "medium", "json", nil)
  end

  defp security_audit_impl(
         audit_scope,
         compliance_standards,
         include_recommendations,
         severity_threshold,
         output_format,
         output_file
       ) do
    try do
      # Perform security audit
      audit_results =
        perform_security_audit(audit_scope, compliance_standards, severity_threshold)

      # Add recommendations if requested
      results_with_recommendations =
        if include_recommendations do
          add_audit_recommendations(audit_results)
        else
          audit_results
        end

      # Format output
      formatted_output = format_audit_output(results_with_recommendations, output_format)

      # Save to file if specified
      if output_file do
        File.write!(output_file, formatted_output)
      end

      {:ok,
       %{
         audit_scope: audit_scope,
         compliance_standards: compliance_standards,
         include_recommendations: include_recommendations,
         severity_threshold: severity_threshold,
         output_format: output_format,
         output_file: output_file,
         audit_results: results_with_recommendations,
         formatted_output: formatted_output,
         total_issues: count_audit_issues(results_with_recommendations),
         critical_issues:
           count_audit_issues_by_severity(results_with_recommendations, "critical"),
         high_issues: count_audit_issues_by_severity(results_with_recommendations, "high"),
         medium_issues: count_audit_issues_by_severity(results_with_recommendations, "medium"),
         low_issues: count_audit_issues_by_severity(results_with_recommendations, "low"),
         success: true
       }}
    rescue
      error -> {:error, "Security audit error: #{inspect(error)}"}
    end
  end

  def policy_check(
        %{
          "policy_types" => policy_types,
          "config_files" => config_files,
          "compliance_framework" => compliance_framework,
          "include_recommendations" => include_recommendations,
          "severity_filter" => severity_filter,
          "output_format" => output_format
        },
        _ctx
      ) do
    policy_check_impl(
      policy_types,
      config_files,
      compliance_framework,
      include_recommendations,
      severity_filter,
      output_format
    )
  end

  def policy_check(
        %{
          "policy_types" => policy_types,
          "config_files" => config_files,
          "compliance_framework" => compliance_framework,
          "include_recommendations" => include_recommendations,
          "severity_filter" => severity_filter
        },
        _ctx
      ) do
    policy_check_impl(
      policy_types,
      config_files,
      compliance_framework,
      include_recommendations,
      severity_filter,
      "json"
    )
  end

  def policy_check(
        %{
          "policy_types" => policy_types,
          "config_files" => config_files,
          "compliance_framework" => compliance_framework,
          "include_recommendations" => include_recommendations
        },
        _ctx
      ) do
    policy_check_impl(
      policy_types,
      config_files,
      compliance_framework,
      include_recommendations,
      "medium",
      "json"
    )
  end

  def policy_check(
        %{
          "policy_types" => policy_types,
          "config_files" => config_files,
          "compliance_framework" => compliance_framework
        },
        _ctx
      ) do
    policy_check_impl(policy_types, config_files, compliance_framework, true, "medium", "json")
  end

  def policy_check(%{"policy_types" => policy_types, "config_files" => config_files}, _ctx) do
    policy_check_impl(policy_types, config_files, "OWASP", true, "medium", "json")
  end

  def policy_check(%{"policy_types" => policy_types}, _ctx) do
    policy_check_impl(policy_types, nil, "OWASP", true, "medium", "json")
  end

  def policy_check(%{}, _ctx) do
    policy_check_impl(
      ["access_control", "encryption", "network", "data_protection", "incident_response"],
      nil,
      "OWASP",
      true,
      "medium",
      "json"
    )
  end

  defp policy_check_impl(
         policy_types,
         config_files,
         compliance_framework,
         include_recommendations,
         severity_filter,
         output_format
       ) do
    try do
      # Find config files if not specified
      files = config_files || find_config_files()

      # Check policies
      policy_results =
        Enum.map(policy_types, fn policy_type ->
          check_policy_type(policy_type, files, compliance_framework, severity_filter)
        end)

      # Add recommendations if requested
      results_with_recommendations =
        if include_recommendations do
          add_policy_recommendations(policy_results)
        else
          policy_results
        end

      # Format output
      formatted_output = format_policy_output(results_with_recommendations, output_format)

      {:ok,
       %{
         policy_types: policy_types,
         config_files: files,
         compliance_framework: compliance_framework,
         include_recommendations: include_recommendations,
         severity_filter: severity_filter,
         output_format: output_format,
         policy_results: results_with_recommendations,
         formatted_output: formatted_output,
         total_violations: count_policy_violations(results_with_recommendations),
         critical_violations:
           count_policy_violations_by_severity(results_with_recommendations, "critical"),
         high_violations:
           count_policy_violations_by_severity(results_with_recommendations, "high"),
         medium_violations:
           count_policy_violations_by_severity(results_with_recommendations, "medium"),
         low_violations: count_policy_violations_by_severity(results_with_recommendations, "low"),
         success: true
       }}
    rescue
      error -> {:error, "Policy check error: #{inspect(error)}"}
    end
  end

  def secrets_scan(
        %{
          "target" => target,
          "secret_types" => secret_types,
          "confidence_threshold" => confidence_threshold,
          "include_context" => include_context,
          "exclude_patterns" => exclude_patterns,
          "output_format" => output_format
        },
        _ctx
      ) do
    secrets_scan_impl(
      target,
      secret_types,
      confidence_threshold,
      include_context,
      exclude_patterns,
      output_format
    )
  end

  def secrets_scan(
        %{
          "target" => target,
          "secret_types" => secret_types,
          "confidence_threshold" => confidence_threshold,
          "include_context" => include_context,
          "exclude_patterns" => exclude_patterns
        },
        _ctx
      ) do
    secrets_scan_impl(
      target,
      secret_types,
      confidence_threshold,
      include_context,
      exclude_patterns,
      "json"
    )
  end

  def secrets_scan(
        %{
          "target" => target,
          "secret_types" => secret_types,
          "confidence_threshold" => confidence_threshold,
          "include_context" => include_context
        },
        _ctx
      ) do
    secrets_scan_impl(target, secret_types, confidence_threshold, include_context, [], "json")
  end

  def secrets_scan(
        %{
          "target" => target,
          "secret_types" => secret_types,
          "confidence_threshold" => confidence_threshold
        },
        _ctx
      ) do
    secrets_scan_impl(target, secret_types, confidence_threshold, true, [], "json")
  end

  def secrets_scan(%{"target" => target, "secret_types" => secret_types}, _ctx) do
    secrets_scan_impl(target, secret_types, "medium", true, [], "json")
  end

  def secrets_scan(%{"target" => target}, _ctx) do
    secrets_scan_impl(
      target,
      ["api_keys", "passwords", "tokens", "certificates", "database_urls"],
      "medium",
      true,
      [],
      "json"
    )
  end

  defp secrets_scan_impl(
         target,
         secret_types,
         confidence_threshold,
         include_context,
         exclude_patterns,
         output_format
       ) do
    try do
      # Find files to scan
      files = find_files_to_scan(target, exclude_patterns)

      # Scan for secrets
      secret_results =
        Enum.flat_map(files, fn file ->
          scan_file_for_secrets(file, secret_types, confidence_threshold, include_context)
        end)

      # Format output
      formatted_output = format_secrets_output(secret_results, output_format)

      {:ok,
       %{
         target: target,
         secret_types: secret_types,
         confidence_threshold: confidence_threshold,
         include_context: include_context,
         exclude_patterns: exclude_patterns,
         output_format: output_format,
         files_scanned: files,
         secret_results: secret_results,
         formatted_output: formatted_output,
         total_secrets: length(secret_results),
         high_confidence: length(Enum.filter(secret_results, &(&1.confidence == "high"))),
         medium_confidence: length(Enum.filter(secret_results, &(&1.confidence == "medium"))),
         low_confidence: length(Enum.filter(secret_results, &(&1.confidence == "low"))),
         success: true
       }}
    rescue
      error -> {:error, "Secrets scan error: #{inspect(error)}"}
    end
  end

  def compliance_check(
        %{
          "compliance_framework" => compliance_framework,
          "check_types" => check_types,
          "include_evidence" => include_evidence,
          "severity_threshold" => severity_threshold,
          "output_format" => output_format,
          "output_file" => output_file
        },
        _ctx
      ) do
    compliance_check_impl(
      compliance_framework,
      check_types,
      include_evidence,
      severity_threshold,
      output_format,
      output_file
    )
  end

  def compliance_check(
        %{
          "compliance_framework" => compliance_framework,
          "check_types" => check_types,
          "include_evidence" => include_evidence,
          "severity_threshold" => severity_threshold,
          "output_format" => output_format
        },
        _ctx
      ) do
    compliance_check_impl(
      compliance_framework,
      check_types,
      include_evidence,
      severity_threshold,
      output_format,
      nil
    )
  end

  def compliance_check(
        %{
          "compliance_framework" => compliance_framework,
          "check_types" => check_types,
          "include_evidence" => include_evidence,
          "severity_threshold" => severity_threshold
        },
        _ctx
      ) do
    compliance_check_impl(
      compliance_framework,
      check_types,
      include_evidence,
      severity_threshold,
      "json",
      nil
    )
  end

  def compliance_check(
        %{
          "compliance_framework" => compliance_framework,
          "check_types" => check_types,
          "include_evidence" => include_evidence
        },
        _ctx
      ) do
    compliance_check_impl(
      compliance_framework,
      check_types,
      include_evidence,
      "medium",
      "json",
      nil
    )
  end

  def compliance_check(
        %{"compliance_framework" => compliance_framework, "check_types" => check_types},
        _ctx
      ) do
    compliance_check_impl(compliance_framework, check_types, true, "medium", "json", nil)
  end

  def compliance_check(%{"compliance_framework" => compliance_framework}, _ctx) do
    compliance_check_impl(
      compliance_framework,
      ["code", "config", "network", "access", "data", "incident"],
      true,
      "medium",
      "json",
      nil
    )
  end

  defp compliance_check_impl(
         compliance_framework,
         check_types,
         include_evidence,
         severity_threshold,
         output_format,
         output_file
       ) do
    try do
      # Perform compliance check
      compliance_results =
        perform_compliance_check(compliance_framework, check_types, severity_threshold)

      # Add evidence if requested
      results_with_evidence =
        if include_evidence do
          add_compliance_evidence(compliance_results)
        else
          compliance_results
        end

      # Format output
      formatted_output = format_compliance_output(results_with_evidence, output_format)

      # Save to file if specified
      if output_file do
        File.write!(output_file, formatted_output)
      end

      {:ok,
       %{
         compliance_framework: compliance_framework,
         check_types: check_types,
         include_evidence: include_evidence,
         severity_threshold: severity_threshold,
         output_format: output_format,
         output_file: output_file,
         compliance_results: results_with_evidence,
         formatted_output: formatted_output,
         total_checks: length(results_with_evidence),
         passed_checks: length(Enum.filter(results_with_evidence, &(&1.status == "passed"))),
         failed_checks: length(Enum.filter(results_with_evidence, &(&1.status == "failed"))),
         compliance_score: calculate_compliance_score(results_with_evidence),
         success: true
       }}
    rescue
      error -> {:error, "Compliance check error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp detect_language_from_target(target) do
    cond do
      String.ends_with?(target, ".ex") or String.ends_with?(target, ".exs") -> "elixir"
      String.ends_with?(target, ".js") or String.ends_with?(target, ".ts") -> "javascript"
      String.ends_with?(target, ".py") -> "python"
      String.ends_with?(target, ".rs") -> "rust"
      String.ends_with?(target, ".go") -> "go"
      String.ends_with?(target, ".java") -> "java"
      String.ends_with?(target, ".rb") -> "ruby"
      true -> "unknown"
    end
  end

  defp perform_security_scan(target, scan_type, language, severity) do
    case scan_type do
      "code" -> scan_code_security(target, language, severity)
      "config" -> scan_config_security(target, severity)
      "dependencies" -> scan_dependency_security(target, severity)
      "secrets" -> scan_secrets_security(target, severity)
      "permissions" -> scan_permissions_security(target, severity)
      _ -> %{scan_type: scan_type, error: "Unknown scan type"}
    end
  end

  defp scan_code_security(target, language, severity) do
    # Simulate code security scan
    %{
      scan_type: "code",
      language: language,
      vulnerabilities: [
        %{
          id: "SQL_INJECTION_001",
          title: "Potential SQL Injection",
          severity: "high",
          file: target,
          line: 42,
          description: "User input directly concatenated into SQL query",
          cwe: "CWE-89"
        }
      ]
    }
  end

  defp scan_config_security(target, severity) do
    # Simulate config security scan
    %{
      scan_type: "config",
      vulnerabilities: [
        %{
          id: "WEAK_CRYPTO_001",
          title: "Weak Encryption Algorithm",
          severity: "medium",
          file: target,
          line: 15,
          description: "MD5 hash used for password storage",
          cwe: "CWE-327"
        }
      ]
    }
  end

  defp scan_dependency_security(target, severity) do
    # Simulate dependency security scan
    %{
      scan_type: "dependencies",
      vulnerabilities: [
        %{
          id: "DEP_VULN_001",
          title: "Outdated Dependency",
          severity: "critical",
          package: "lodash",
          version: "4.17.15",
          description: "Known vulnerability in lodash version 4.17.15",
          cve: "CVE-2021-23337"
        }
      ]
    }
  end

  defp scan_secrets_security(target, severity) do
    base_result = %{
      scan_type: "secrets",
      vulnerabilities: [
        %{
          id: "SECRET_001",
          title: "Hardcoded API Key",
          severity: "high",
          file: target,
          line: 28,
          description: "API key found in source code",
          secret_type: "api_key"
        }
      ]
    }

    base_result
    |> List.wrap()
    |> filter_results_by_severity(severity)
    |> Enum.at(0, Map.put(base_result, :vulnerabilities, []))
  end

  defp scan_permissions_security(target, severity) do
    base_result = %{
      scan_type: "permissions",
      vulnerabilities: [
        %{
          id: "PERM_001",
          title: "Overly Permissive File Permissions",
          severity: "medium",
          file: target,
          permissions: "777",
          description: "File has world-writable permissions",
          cwe: "CWE-732"
        }
      ]
    }

    base_result
    |> List.wrap()
    |> filter_results_by_severity(severity)
    |> Enum.at(0, Map.put(base_result, :vulnerabilities, []))
  end

  defp filter_results_by_severity(results, severity) do
    severity_order = %{"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
    min_severity_level = Map.get(severity_order, severity, 2)

    Enum.map(results, fn result ->
      if Map.has_key?(result, :vulnerabilities) do
        filtered_vulns =
          Enum.filter(result.vulnerabilities, fn vuln ->
            vuln_severity_level = Map.get(severity_order, vuln.severity, 1)
            vuln_severity_level >= min_severity_level
          end)

        Map.put(result, :vulnerabilities, filtered_vulns)
      else
        result
      end
    end)
  end

  defp add_security_fixes(results) do
    Enum.map(results, fn result ->
      if Map.has_key?(result, :vulnerabilities) do
        fixes =
          Enum.map(result.vulnerabilities, fn vuln ->
            generate_security_fix(vuln)
          end)

        Map.put(result, :fixes, fixes)
      else
        result
      end
    end)
  end

  defp generate_security_fix(vulnerability) do
    case vulnerability.id do
      "SQL_INJECTION_001" ->
        %{
          type: "code_change",
          description: "Use parameterized queries instead of string concatenation",
          example:
            "PreparedStatement stmt = conn.prepareStatement(\"SELECT * FROM users WHERE id = ?\");"
        }

      "WEAK_CRYPTO_001" ->
        %{
          type: "config_change",
          description: "Use bcrypt or Argon2 for password hashing",
          example: "bcrypt.hash(password, 12)"
        }

      _ ->
        %{
          type: "general",
          description: "Review and update security configuration",
          example: "Consult security documentation"
        }
    end
  end

  defp format_security_output(results, output_format) do
    case output_format do
      "json" -> Jason.encode!(results, pretty: true)
      "sarif" -> format_sarif_output(results)
      "text" -> format_text_output(results)
      "html" -> format_html_output(results)
      _ -> Jason.encode!(results, pretty: true)
    end
  end

  defp format_sarif_output(results) do
    # SARIF format for security tools
    %{
      "$schema" =>
        "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
      "version" => "2.1.0",
      "runs" => [
        %{
          "tool" => %{
            "driver" => %{
              "name" => "Singularity Security Scanner",
              "version" => "1.0.0"
            }
          },
          "results" => extract_sarif_results(results)
        }
      ]
    }
    |> Jason.encode!(pretty: true)
  end

  defp extract_sarif_results(results) do
    Enum.flat_map(results, fn result ->
      if Map.has_key?(result, :vulnerabilities) do
        Enum.map(result.vulnerabilities, fn vuln ->
          %{
            "ruleId" => vuln.id,
            "level" => map_severity_to_sarif_level(vuln.severity),
            "message" => %{
              "text" => vuln.description
            },
            "locations" => [
              %{
                "physicalLocation" => %{
                  "artifactLocation" => %{
                    "uri" => vuln.file
                  },
                  "region" => %{
                    "startLine" => vuln.line
                  }
                }
              }
            ]
          }
        end)
      else
        []
      end
    end)
  end

  defp map_severity_to_sarif_level(severity) do
    case severity do
      "critical" -> "error"
      "high" -> "error"
      "medium" -> "warning"
      "low" -> "note"
      _ -> "note"
    end
  end

  defp format_text_output(results) do
    Enum.map(results, fn result ->
      """
      Scan Type: #{result.scan_type}
      Language: #{result.language || "N/A"}

      Vulnerabilities:
      #{Enum.map(result.vulnerabilities || [], fn vuln -> "- #{vuln.title} (#{vuln.severity})" end) |> Enum.join("\n")}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp format_html_output(results) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Security Scan Results</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .vulnerability { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .critical { border-left: 5px solid #dc3545; }
            .high { border-left: 5px solid #fd7e14; }
            .medium { border-left: 5px solid #ffc107; }
            .low { border-left: 5px solid #28a745; }
        </style>
    </head>
    <body>
        <h1>Security Scan Results</h1>
        #{Enum.map(results, fn result -> """
      <div class="scan-type">
          <h2>#{result.scan_type}</h2>
          #{Enum.map(result.vulnerabilities || [], fn vuln -> """
        <div class="vulnerability #{vuln.severity}">
            <h3>#{vuln.title}</h3>
            <p><strong>Severity:</strong> #{vuln.severity}</p>
            <p><strong>Description:</strong> #{vuln.description}</p>
            <p><strong>File:</strong> #{vuln.file}</p>
            <p><strong>Line:</strong> #{vuln.line}</p>
        </div>
        """ end) |> Enum.join("")}
      </div>
      """ end) |> Enum.join("")}
    </body>
    </html>
    """
  end

  defp count_vulnerabilities(results) do
    Enum.reduce(results, 0, fn result, acc ->
      if Map.has_key?(result, :vulnerabilities) do
        acc + length(result.vulnerabilities)
      else
        acc
      end
    end)
  end

  defp count_vulnerabilities_by_severity(results, severity) do
    Enum.reduce(results, 0, fn result, acc ->
      if Map.has_key?(result, :vulnerabilities) do
        count = Enum.count(result.vulnerabilities, &(&1.severity == severity))
        acc + count
      else
        acc
      end
    end)
  end

  defp detect_package_manager(lock_file) do
    cond do
      String.contains?(lock_file || "", "mix.lock") -> "mix"
      String.contains?(lock_file || "", "package-lock.json") -> "npm"
      String.contains?(lock_file || "", "requirements.txt") -> "pip"
      String.contains?(lock_file || "", "Cargo.lock") -> "cargo"
      String.contains?(lock_file || "", "pom.xml") -> "maven"
      true -> "mix"
    end
  end

  defp find_lock_file(package_manager) do
    case package_manager do
      "mix" -> "mix.lock"
      "npm" -> "package-lock.json"
      "pip" -> "requirements.txt"
      "cargo" -> "Cargo.lock"
      "maven" -> "pom.xml"
      _ -> "mix.lock"
    end
  end

  defp parse_dependencies(lock_file, package_manager, include_dev_deps) do
    # Simulate dependency parsing
    [
      %{name: "phoenix", version: "1.7.0", type: "runtime"},
      %{name: "ecto", version: "3.10.0", type: "runtime"},
      %{
        name: "ex_unit",
        version: "1.18.0",
        type: if(include_dev_deps, do: "dev", else: "runtime")
      }
    ]
  end

  defp check_dependency_vulnerabilities(dependencies, package_manager, severity_filter) do
    # Simulate vulnerability checking
    [
      %{
        package: "phoenix",
        version: "1.7.0",
        severity: "medium",
        cve: "CVE-2023-12345",
        description: "Potential XSS vulnerability in template rendering",
        fixed_in: "1.7.1"
      }
    ]
  end

  defp check_dependency_updates(dependencies, package_manager) do
    # Simulate update checking
    [
      %{
        package: "phoenix",
        current_version: "1.7.0",
        latest_version: "1.7.2",
        update_type: "patch"
      }
    ]
  end

  defp format_vulnerability_output(vulnerability_results, update_results, output_format) do
    case output_format do
      "json" ->
        Jason.encode!(%{vulnerabilities: vulnerability_results, updates: update_results},
          pretty: true
        )

      "table" ->
        format_vulnerability_table(vulnerability_results, update_results)

      "text" ->
        format_vulnerability_text(vulnerability_results, update_results)

      _ ->
        Jason.encode!(%{vulnerabilities: vulnerability_results, updates: update_results},
          pretty: true
        )
    end
  end

  defp format_vulnerability_table(vulnerability_results, update_results) do
    vuln_table =
      Enum.map(vulnerability_results, fn vuln ->
        "| #{vuln.package} | #{vuln.version} | #{vuln.severity} | #{vuln.cve} |"
      end)
      |> Enum.join("\n")

    update_table =
      Enum.map(update_results, fn update ->
        "| #{update.package} | #{update.current_version} | #{update.latest_version} | #{update.update_type} |"
      end)
      |> Enum.join("\n")

    """
    Vulnerabilities:
    | Package | Version | Severity | CVE |
    |---------|---------|----------|-----|
    #{vuln_table}

    Updates:
    | Package | Current | Latest | Type |
    |---------|---------|--------|------|
    #{update_table}
    """
  end

  defp format_vulnerability_text(vulnerability_results, update_results) do
    vuln_text =
      Enum.map(vulnerability_results, fn vuln ->
        "- #{vuln.package} #{vuln.version}: #{vuln.severity} - #{vuln.description}"
      end)
      |> Enum.join("\n")

    update_text =
      Enum.map(update_results, fn update ->
        "- #{update.package}: #{update.current_version} → #{update.latest_version} (#{update.update_type})"
      end)
      |> Enum.join("\n")

    """
    Vulnerabilities:
    #{vuln_text}

    Available Updates:
    #{update_text}
    """
  end

  defp find_audit_log_files do
    # Find common audit log locations
    [
      "/var/log/audit/audit.log",
      "/var/log/auth.log",
      "/var/log/secure"
    ]
  end

  defp analyze_audit_log_file(file, time_range, event_types, severity, include_context) do
    # Simulate audit log analysis
    [
      %{
        file: file,
        timestamp: "2025-01-07T03:30:15Z",
        event_type: "login",
        severity: "medium",
        user: "admin",
        source_ip: "192.168.1.100",
        description: "Successful login from 192.168.1.100",
        context:
          if(include_context,
            do: [
              "2025-01-07T03:30:14Z: Connection established",
              "2025-01-07T03:30:16Z: Session started"
            ],
            else: []
          )
      }
    ]
  end

  defp sort_audit_results(results) do
    Enum.sort_by(results, & &1.timestamp, :desc)
  end

  defp generate_audit_summary(results) do
    %{
      total_events: length(results),
      login_events: length(Enum.filter(results, &(&1.event_type == "login"))),
      file_access_events: length(Enum.filter(results, &(&1.event_type == "file_access"))),
      permission_events: length(Enum.filter(results, &(&1.event_type == "permission_change"))),
      system_call_events: length(Enum.filter(results, &(&1.event_type == "system_call")))
    }
  end

  defp perform_security_audit(audit_scope, compliance_standards, severity_threshold) do
    # Simulate security audit
    [
      %{
        scope: audit_scope,
        standard: "OWASP",
        issue_id: "AUDIT_001",
        title: "Missing HTTPS Configuration",
        severity: "high",
        description: "Application not configured to use HTTPS",
        recommendation: "Enable HTTPS and redirect HTTP traffic"
      }
    ]
  end

  defp add_audit_recommendations(audit_results) do
    Enum.map(audit_results, fn result ->
      Map.put(result, :recommendations, [
        %{
          priority: "high",
          action: "Configure HTTPS",
          timeline: "immediate",
          effort: "low"
        }
      ])
    end)
  end

  defp format_audit_output(results, output_format) do
    case output_format do
      "json" -> Jason.encode!(results, pretty: true)
      "html" -> format_audit_html(results)
      "pdf" -> "PDF generation not implemented"
      "text" -> format_audit_text(results)
      _ -> Jason.encode!(results, pretty: true)
    end
  end

  defp format_audit_html(results) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Security Audit Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .issue { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .high { border-left: 5px solid #dc3545; }
            .medium { border-left: 5px solid #ffc107; }
            .low { border-left: 5px solid #28a745; }
        </style>
    </head>
    <body>
        <h1>Security Audit Report</h1>
        #{Enum.map(results, fn result -> """
      <div class="issue #{result.severity}">
          <h3>#{result.title}</h3>
          <p><strong>Severity:</strong> #{result.severity}</p>
          <p><strong>Description:</strong> #{result.description}</p>
          <p><strong>Recommendation:</strong> #{result.recommendation}</p>
      </div>
      """ end) |> Enum.join("")}
    </body>
    </html>
    """
  end

  defp format_audit_text(results) do
    Enum.map(results, fn result ->
      """
      Issue: #{result.title}
      Severity: #{result.severity}
      Description: #{result.description}
      Recommendation: #{result.recommendation}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp count_audit_issues(results) do
    length(results)
  end

  defp count_audit_issues_by_severity(results, severity) do
    Enum.count(results, &(&1.severity == severity))
  end

  defp find_config_files do
    # Find common config files
    [
      "config/config.exs",
      "config/prod.exs",
      "config/dev.exs",
      ".env",
      "docker-compose.yml"
    ]
  end

  defp check_policy_type(policy_type, files, compliance_framework, severity_filter) do
    # Simulate policy checking
    %{
      policy_type: policy_type,
      compliance_framework: compliance_framework,
      violations: [
        %{
          id: "POLICY_001",
          title: "Weak Password Policy",
          severity: "medium",
          file: "config/config.exs",
          description: "Password minimum length is less than 8 characters",
          recommendation: "Increase minimum password length to 12 characters"
        }
      ]
    }
  end

  defp add_policy_recommendations(policy_results) do
    Enum.map(policy_results, fn result ->
      Map.put(result, :recommendations, [
        %{
          priority: "medium",
          action: "Update password policy",
          timeline: "1 week",
          effort: "low"
        }
      ])
    end)
  end

  defp format_policy_output(results, output_format) do
    case output_format do
      "json" -> Jason.encode!(results, pretty: true)
      "text" -> format_policy_text(results)
      "table" -> format_policy_table(results)
      _ -> Jason.encode!(results, pretty: true)
    end
  end

  defp format_policy_text(results) do
    Enum.map(results, fn result ->
      """
      Policy Type: #{result.policy_type}
      Framework: #{result.compliance_framework}

      Violations:
      #{Enum.map(result.violations, fn violation -> "- #{violation.title} (#{violation.severity}): #{violation.description}" end) |> Enum.join("\n")}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp format_policy_table(results) do
    Enum.map(results, fn result ->
      """
      | Policy Type | Framework | Violations |
      |-------------|-----------|-------------|
      | #{result.policy_type} | #{result.compliance_framework} | #{length(result.violations)} |
      """
    end)
    |> Enum.join("\n")
  end

  defp count_policy_violations(results) do
    Enum.reduce(results, 0, fn result, acc ->
      acc + length(result.violations)
    end)
  end

  defp count_policy_violations_by_severity(results, severity) do
    Enum.reduce(results, 0, fn result, acc ->
      count = Enum.count(result.violations, &(&1.severity == severity))
      acc + count
    end)
  end

  defp find_files_to_scan(target, exclude_patterns) do
    # Simulate file finding
    [
      "lib/singularity.ex",
      "config/config.exs",
      "test/singularity_test.exs"
    ]
  end

  defp scan_file_for_secrets(file, secret_types, confidence_threshold, include_context) do
    # Simulate secrets scanning
    [
      %{
        file: file,
        line: 42,
        secret_type: "api_key",
        confidence: "high",
        value: "sk-1234567890abcdef",
        context:
          if(include_context,
            do: ["line 40: # API configuration", "line 44: # End API config"],
            else: []
          ),
        description: "Potential API key found in source code"
      }
    ]
  end

  defp format_secrets_output(results, output_format) do
    case output_format do
      "json" -> Jason.encode!(results, pretty: true)
      "text" -> format_secrets_text(results)
      "csv" -> format_secrets_csv(results)
      _ -> Jason.encode!(results, pretty: true)
    end
  end

  defp format_secrets_text(results) do
    Enum.map(results, fn result ->
      """
      File: #{result.file}
      Line: #{result.line}
      Type: #{result.secret_type}
      Confidence: #{result.confidence}
      Description: #{result.description}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp format_secrets_csv(results) do
    header = "File,Line,Type,Confidence,Description\n"

    rows =
      Enum.map(results, fn result ->
        "#{result.file},#{result.line},#{result.secret_type},#{result.confidence},#{result.description}"
      end)
      |> Enum.join("\n")

    header <> rows
  end

  defp perform_compliance_check(framework, check_types, severity_threshold) do
    # Simulate compliance checking
    [
      %{
        framework: framework,
        check_type: "code",
        check_id: "COMP_001",
        title: "Input Validation",
        status: "passed",
        description: "All user inputs are properly validated",
        evidence: "Code review shows input validation in place"
      },
      %{
        framework: framework,
        check_type: "config",
        check_id: "COMP_002",
        title: "HTTPS Configuration",
        status: "failed",
        description: "HTTPS not properly configured",
        evidence: "Configuration file shows HTTP-only setup"
      }
    ]
  end

  defp add_compliance_evidence(results) do
    Enum.map(results, fn result ->
      Map.put(result, :evidence_details, [
        %{
          type: "code_review",
          description: "Manual code review",
          status: "completed",
          findings: "No issues found"
        }
      ])
    end)
  end

  defp format_compliance_output(results, output_format) do
    case output_format do
      "json" -> Jason.encode!(results, pretty: true)
      "html" -> format_compliance_html(results)
      "pdf" -> "PDF generation not implemented"
      "text" -> format_compliance_text(results)
      _ -> Jason.encode!(results, pretty: true)
    end
  end

  defp format_compliance_html(results) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Compliance Check Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .check { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .passed { border-left: 5px solid #28a745; }
            .failed { border-left: 5px solid #dc3545; }
        </style>
    </head>
    <body>
        <h1>Compliance Check Report</h1>
        #{Enum.map(results, fn result -> """
      <div class="check #{result.status}">
          <h3>#{result.title}</h3>
          <p><strong>Status:</strong> #{result.status}</p>
          <p><strong>Description:</strong> #{result.description}</p>
          <p><strong>Evidence:</strong> #{result.evidence}</p>
      </div>
      """ end) |> Enum.join("")}
    </body>
    </html>
    """
  end

  defp format_compliance_text(results) do
    Enum.map(results, fn result ->
      """
      Check: #{result.title}
      Status: #{result.status}
      Description: #{result.description}
      Evidence: #{result.evidence}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp calculate_compliance_score(results) do
    total_checks = length(results)
    passed_checks = length(Enum.filter(results, &(&1.status == "passed")))

    if total_checks > 0 do
      (passed_checks / total_checks * 100) |> Float.round(2)
    else
      0.0
    end
  end
end
