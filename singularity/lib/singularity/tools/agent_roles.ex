defmodule Singularity.Tools.AgentRoles do
  @moduledoc """
  Role-based tool management for AI agents.

  Different agent specializations get different tool sets to:
  1. Reduce cognitive load
  2. Improve context management
  3. Focus on relevant capabilities
  4. Prevent tool confusion
  """

  alias Singularity.Tools.Catalog
  import Logger

  @agent_roles %{
    # Core development roles
    :code_developer => %{
      description: "Full-stack developer agent - writes, analyzes, and maintains code",
      tools: [
        # Code understanding
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        "codebase_architecture",
        # Code analysis  
        "code_refactor",
        "code_complexity",
        "code_todos",
        "code_quality",
        # Knowledge
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_examples",
        "package_search",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    },
    :architecture_analyst => %{
      description: "System architecture specialist - analyzes and designs system architecture",
      tools: [
        # Architecture focus
        "codebase_architecture",
        "codebase_dependencies",
        "codebase_services",
        "codebase_analyze",
        "codebase_technologies",
        # Planning
        "planning_work_plan",
        "planning_estimate",
        "planning_dependencies",
        # Knowledge
        "knowledge_frameworks",
        "knowledge_patterns",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },
    :quality_engineer => %{
      description:
        "Code quality specialist - ensures code quality, security, and maintainability",
      tools: [
        # Quality focus
        "code_quality",
        "code_refactor",
        "code_complexity",
        "code_consolidate",
        "code_todos",
        "code_language_analyze",
        # Code understanding
        "codebase_search",
        "codebase_analyze",
        # Knowledge
        "knowledge_duplicates",
        "knowledge_patterns",
        # Quality tools
        "quality_sobelow",
        "quality_mix_audit",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },
    :project_manager => %{
      description: "Project management specialist - plans, prioritizes, and coordinates work",
      tools: [
        # Planning focus
        "planning_work_plan",
        "planning_decompose",
        "planning_prioritize",
        "planning_estimate",
        "planning_dependencies",
        "planning_execute",
        # High-level understanding
        "codebase_architecture",
        "codebase_technologies",
        # Knowledge
        "knowledge_packages",
        "knowledge_frameworks",
        "package_search",
        # Summary tools
        "planning_summary",
        "codebase_summary",
        # Basic tools
        "fs_list_directory",
        "fs_read_file"
      ]
    },
    :knowledge_curator => %{
      description: "Knowledge management specialist - maintains and searches knowledge base",
      tools: [
        # Knowledge focus
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_frameworks",
        "knowledge_examples",
        "package_search",
        "knowledge_duplicates",
        "knowledge_documentation",
        # Search
        "codebase_search",
        "web_search",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },
    :devops_engineer => %{
      description: "DevOps specialist - handles deployment, monitoring, and infrastructure",
      tools: [
        # Infrastructure focus
        "codebase_services",
        "codebase_technologies",
        "codebase_dependencies",
        # Analysis
        "code_language_analyze",
        "code_quality",
        # Knowledge
        "knowledge_packages",
        "knowledge_frameworks",
        # Shell tools
        "sh_run_command",
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },

    # Language specialist (polyglot)
    :language_specialist => %{
      description:
        "Language specialist - focuses on code analysis and optimization across all supported languages",
      tools: [
        # Language analysis focus
        "code_language_analyze",
        "code_quality",
        "code_complexity",
        # Code understanding
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        # Knowledge
        "knowledge_packages",
        "knowledge_patterns",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    },
    :generalist => %{
      description: "General purpose agent - has access to most tools for broad tasks",
      tools: [
        # Core understanding
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        # Planning
        "planning_work_plan",
        "planning_decompose",
        "planning_estimate",
        # Knowledge
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_examples",
        # Analysis
        "code_quality",
        "code_refactor",
        "code_todos",
        # Summary
        "tools_summary",
        "codebase_summary",
        "planning_summary",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    }
  }

  @doc """
  Get available agent roles and their descriptions.
  """
  def get_roles do
    @agent_roles
  end

  @doc """
  Get tools for a specific agent role.
  """
  def get_tools_for_role(role) when is_atom(role) do
    case Map.get(@agent_roles, role) do
      nil -> {:error, "Unknown role: #{role}"}
      role_info -> {:ok, role_info.tools}
    end
  end

  @doc """
  Get role description and tool count.
  """
  def get_role_info(role) when is_atom(role) do
    case Map.get(@agent_roles, role) do
      nil ->
        {:error, "Unknown role: #{role}"}

      role_info ->
        {:ok,
         %{
           role: role,
           description: role_info.description,
           tool_count: length(role_info.tools),
           tools: role_info.tools
         }}
    end
  end

  @doc """
  Register tools for a specific agent role.
  """
  def add_tools_for_role(provider, role) when is_atom(role) do
    case get_tools_for_role(role) do
      {:ok, tool_names} ->
        # Register only the tools for this role
        tools = load_tools_by_names(tool_names)
        Singularity.Tools.Catalog.add_tools(provider, tools)
        {:ok, length(tools)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get recommended role based on task description.
  """
  def recommend_role(task_description) when is_binary(task_description) do
    task_lower = String.downcase(task_description)

    cond do
      # Architecture keywords
      String.contains?(task_lower, ["architecture", "design", "system", "microservice", "service"]) ->
        :architecture_analyst

      # Quality keywords  
      String.contains?(task_lower, ["quality", "refactor", "clean", "security", "audit", "review"]) ->
        :quality_engineer

      # Planning keywords
      String.contains?(task_lower, [
        "plan",
        "prioritize",
        "estimate",
        "project",
        "manage",
        "coordinate"
      ]) ->
        :project_manager

      # Knowledge keywords
      String.contains?(task_lower, [
        "document",
        "search",
        "find",
        "pattern",
        "example",
        "knowledge"
      ]) ->
        :knowledge_curator

      # DevOps keywords
      String.contains?(task_lower, [
        "deploy",
        "infrastructure",
        "monitor",
        "ops",
        "devops",
        "ci/cd"
      ]) ->
        :devops_engineer

      # Language analysis keywords
      String.contains?(task_lower, [
        "analyze",
        "optimize",
        "performance",
        "security",
        "dependencies",
        "language"
      ]) ->
        :language_specialist

      # Default to generalist
      true ->
        :generalist
    end
  end

  # Private functions

  defp load_tools_by_names(tool_names) do
    # Load actual tool definitions by name from existing tool modules
    try do
      tool_names
      |> Enum.map(&load_single_tool/1)
      |> Enum.filter(&(&1 != nil))
    rescue
      error ->
        Logger.warning("Failed to load tools by names: #{inspect(error)}")
        # Fallback to basic tool definitions
        Enum.map(tool_names, fn name ->
          %{name: name, description: "Tool: #{name}", status: "fallback"}
        end)
    end
  end

  defp load_single_tool(tool_name) do
    # Load individual tool definition based on name
    case tool_name do
      "code_analysis" -> load_code_analysis_tool()
      "quality_assurance" -> load_quality_assurance_tool()
      "testing" -> load_testing_tool()
      "security" -> load_security_tool()
      "performance" -> load_performance_tool()
      "deployment" -> load_deployment_tool()
      "monitoring" -> load_monitoring_tool()
      "documentation" -> load_documentation_tool()
      "database" -> load_database_tool()
      "file_system" -> load_file_system_tool()
      "git" -> load_git_tool()
      "nats" -> load_nats_tool()
      "analytics" -> load_analytics_tool()
      "backup" -> load_backup_tool()
      "communication" -> load_communication_tool()
      "integration" -> load_integration_tool()
      "development" -> load_development_tool()
      "process_system" -> load_process_system_tool()
      "code_generation" -> load_code_generation_tool()
      "code_naming" -> load_code_naming_tool()
      _ -> load_generic_tool(tool_name)
    end
  end

  defp load_code_analysis_tool do
    %{
      name: "code_analysis",
      description: "Comprehensive code analysis across multiple languages",
      capabilities: [
        "Multi-language analysis (Elixir, Rust, TypeScript, Python, Go, Java)",
        "Security vulnerability detection",
        "Code quality assessment",
        "Dependency analysis",
        "Architecture pattern detection"
      ],
      status: "active",
      module: "Singularity.Tools.CodeAnalysis"
    }
  end

  defp load_quality_assurance_tool do
    %{
      name: "quality_assurance",
      description: "Code quality assurance and testing tools",
      capabilities: [
        "Unit testing",
        "Integration testing",
        "Code coverage analysis",
        "Quality metrics calculation",
        "Test automation"
      ],
      status: "active",
      module: "Singularity.Tools.QualityAssurance"
    }
  end

  defp load_testing_tool do
    %{
      name: "testing",
      description: "Comprehensive testing framework and tools",
      capabilities: [
        "Test execution",
        "Test result analysis",
        "Performance testing",
        "Load testing",
        "Test reporting"
      ],
      status: "active",
      module: "Singularity.Tools.Testing"
    }
  end

  defp load_security_tool do
    %{
      name: "security",
      description: "Security analysis and vulnerability detection",
      capabilities: [
        "Security scanning",
        "Vulnerability assessment",
        "Security policy enforcement",
        "Threat modeling",
        "Security reporting"
      ],
      status: "active",
      module: "Singularity.Tools.Security"
    }
  end

  defp load_performance_tool do
    %{
      name: "performance",
      description: "Performance analysis and optimization tools",
      capabilities: [
        "Performance profiling",
        "Bottleneck identification",
        "Optimization recommendations",
        "Performance monitoring",
        "Resource usage analysis"
      ],
      status: "active",
      module: "Singularity.Tools.Performance"
    }
  end

  defp load_deployment_tool do
    %{
      name: "deployment",
      description: "Deployment automation and infrastructure management",
      capabilities: [
        "Deployment automation",
        "Infrastructure provisioning",
        "Configuration management",
        "Rollback capabilities",
        "Deployment monitoring"
      ],
      status: "active",
      module: "Singularity.Tools.Deployment"
    }
  end

  defp load_monitoring_tool do
    %{
      name: "monitoring",
      description: "System monitoring and observability tools",
      capabilities: [
        "System metrics collection",
        "Log analysis",
        "Alerting",
        "Performance monitoring",
        "Health checks"
      ],
      status: "active",
      module: "Singularity.Tools.Monitoring"
    }
  end

  defp load_documentation_tool do
    %{
      name: "documentation",
      description: "Documentation generation and management",
      capabilities: [
        "API documentation generation",
        "Code documentation",
        "Architecture documentation",
        "User guides",
        "Documentation validation"
      ],
      status: "active",
      module: "Singularity.Tools.Documentation"
    }
  end

  defp load_database_tool do
    %{
      name: "database",
      description: "Database management and analysis tools",
      capabilities: [
        "Database schema analysis",
        "Query optimization",
        "Database migration",
        "Data validation",
        "Database monitoring"
      ],
      status: "active",
      module: "Singularity.Tools.Database"
    }
  end

  defp load_file_system_tool do
    %{
      name: "file_system",
      description: "File system operations and analysis",
      capabilities: [
        "File operations",
        "Directory analysis",
        "File search",
        "File monitoring",
        "Disk usage analysis"
      ],
      status: "active",
      module: "Singularity.Tools.FileSystem"
    }
  end

  defp load_git_tool do
    %{
      name: "git",
      description: "Git repository management and analysis",
      capabilities: [
        "Git operations",
        "Repository analysis",
        "Commit history analysis",
        "Branch management",
        "Git workflow automation"
      ],
      status: "active",
      module: "Singularity.Tools.Git"
    }
  end

  defp load_nats_tool do
    %{
      name: "nats",
      description: "NATS messaging system integration",
      capabilities: [
        "NATS message publishing",
        "NATS subscription management",
        "Message routing",
        "NATS monitoring",
        "Message queuing"
      ],
      status: "active",
      module: "Singularity.Tools.Nats"
    }
  end

  defp load_analytics_tool do
    %{
      name: "analytics",
      description: "Data analytics and reporting tools",
      capabilities: [
        "Data analysis",
        "Statistical analysis",
        "Report generation",
        "Data visualization",
        "Trend analysis"
      ],
      status: "active",
      module: "Singularity.Tools.Analytics"
    }
  end

  defp load_backup_tool do
    %{
      name: "backup",
      description: "Backup and recovery tools",
      capabilities: [
        "Data backup",
        "Backup verification",
        "Recovery operations",
        "Backup scheduling",
        "Backup monitoring"
      ],
      status: "active",
      module: "Singularity.Tools.Backup"
    }
  end

  defp load_communication_tool do
    %{
      name: "communication",
      description: "Communication and notification tools",
      capabilities: [
        "Email notifications",
        "Slack integration",
        "Webhook notifications",
        "Message templates",
        "Communication logging"
      ],
      status: "active",
      module: "Singularity.Tools.Communication"
    }
  end

  defp load_integration_tool do
    %{
      name: "integration",
      description: "System integration and API management",
      capabilities: [
        "API integration",
        "Data synchronization",
        "Webhook management",
        "Integration testing",
        "API monitoring"
      ],
      status: "active",
      module: "Singularity.Tools.Integration"
    }
  end

  defp load_development_tool do
    %{
      name: "development",
      description: "Development environment and tooling",
      capabilities: [
        "Development environment setup",
        "Code generation",
        "Development workflow automation",
        "Development monitoring",
        "Development analytics"
      ],
      status: "active",
      module: "Singularity.Tools.Development"
    }
  end

  defp load_process_system_tool do
    %{
      name: "process_system",
      description: "Process and system management tools",
      capabilities: [
        "Process monitoring",
        "System resource management",
        "Process automation",
        "System health checks",
        "Process optimization"
      ],
      status: "active",
      module: "Singularity.Tools.ProcessSystem"
    }
  end

  defp load_code_generation_tool do
    %{
      name: "code_generation",
      description: "Automated code generation and scaffolding",
      capabilities: [
        "Code scaffolding",
        "Template-based generation",
        "Code refactoring",
        "Code optimization",
        "Code generation validation"
      ],
      status: "active",
      module: "Singularity.Tools.CodeGeneration"
    }
  end

  defp load_code_naming_tool do
    %{
      name: "code_naming",
      description: "Intelligent code naming and suggestion tools",
      capabilities: [
        "Variable naming suggestions",
        "Function naming suggestions",
        "Class naming suggestions",
        "Naming convention enforcement",
        "Naming quality assessment"
      ],
      status: "active",
      module: "Singularity.Tools.CodeNaming"
    }
  end

  defp load_generic_tool(tool_name) do
    # Generic tool definition for unknown tools
    %{
      name: tool_name,
      description: "Generic tool: #{tool_name}",
      capabilities: ["Basic functionality"],
      status: "generic",
      module: "Singularity.Tools.Generic"
    }
  end
end
