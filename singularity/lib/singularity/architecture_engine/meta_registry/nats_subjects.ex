defmodule Singularity.MetaRegistry.NatsSubjects do
  @moduledoc """
  NATS subject definitions for meta-registry system.

  ## App-Facing Subjects (Clean, no "meta" prefix)

  These are what the APPLICATION sees and uses:
  - `naming.suggestions` - Get naming suggestions
  - `architecture.patterns` - Get architecture patterns  
  - `quality.checks` - Get quality suggestions
  - `dependencies.analysis` - Get dependency analysis

  ## Internal Meta-Registry Subjects (With "meta" prefix)

  These are what OUR SYSTEM uses internally:
  - `meta.registry.naming` - Store/query naming patterns we learn
  - `meta.registry.architecture` - Store/query architecture patterns we learn
  - `meta.registry.quality` - Store/query quality patterns we learn
  - `meta.registry.dependencies` - Store/query dependency patterns we learn

  ## Tech Stack Detection

  The meta-registry detects the application's tech stack and provides
  the right app-facing subjects based on what the application actually uses.
  """

  # App-facing subjects (what the APPLICATION sees)
  @app_facing_subjects %{
    naming: "analysis.meta.naming.suggestions",
    architecture: "analysis.meta.architecture.patterns",
    quality: "analysis.meta.quality.checks",
    dependencies: "analysis.meta.dependencies.analysis",
    patterns: "analysis.meta.patterns.suggestions",
    templates: "analysis.meta.templates.suggestions",
    refactoring: "analysis.meta.refactoring.suggestions"
  }

  # Internal meta-registry subjects (what OUR SYSTEM uses)
  @meta_subjects %{
    naming: "analysis.meta.registry.naming",
    architecture: "analysis.meta.registry.architecture",
    quality: "analysis.meta.registry.quality",
    dependencies: "analysis.meta.registry.dependencies",
    patterns: "analysis.meta.registry.patterns",
    templates: "analysis.meta.registry.templates",
    refactoring: "analysis.meta.registry.refactoring"
  }

  # Usage tracking subjects
  @usage_subjects %{
    naming: "analysis.meta.usage.naming",
    architecture: "analysis.meta.usage.architecture",
    quality: "analysis.meta.usage.quality",
    dependencies: "analysis.meta.usage.dependencies",
    patterns: "analysis.meta.usage.patterns",
    templates: "analysis.meta.usage.templates",
    refactoring: "analysis.meta.usage.refactoring"
  }

  @doc """
  Get app-facing subject for a given category.

  ## Examples

      iex> NatsSubjects.app_facing(:naming)
      "analysis.meta.naming.suggestions"
      
      iex> NatsSubjects.app_facing(:architecture)
      "analysis.meta.architecture.patterns"
  """
  def app_facing(category) when is_atom(category) do
    Map.get(@app_facing_subjects, category, "analysis.meta.unknown.suggestions")
  end

  @doc """
  Get internal meta-registry subject for a given category.

  ## Examples

      iex> NatsSubjects.meta(:naming)
      "analysis.meta.registry.naming"
      
      iex> NatsSubjects.meta(:architecture)
      "analysis.meta.registry.architecture"
  """
  def meta(category) when is_atom(category) do
    Map.get(@meta_subjects, category, "analysis.meta.registry.unknown")
  end

  @doc """
  Get usage tracking subject for a given category.

  ## Examples

      iex> NatsSubjects.usage(:naming)
      "analysis.meta.usage.naming"
      
      iex> NatsSubjects.usage(:architecture)
      "analysis.meta.usage.architecture"
  """
  def usage(category) when is_atom(category) do
    Map.get(@usage_subjects, category, "analysis.meta.usage.unknown")
  end

  @doc """
  Get all app-facing subjects.
  """
  def all_app_facing do
    Map.values(@app_facing_subjects)
  end

  @doc """
  Get all internal meta subjects.
  """
  def all_meta do
    Map.values(@meta_subjects)
  end

  @doc """
  Get all usage tracking subjects.
  """
  def all_usage do
    Map.values(@usage_subjects)
  end

  @doc """
  Convenience helpers returning individual subjects used for subscriptions.
  """
  def naming_suggestions, do: app_facing(:naming)
  def architecture_patterns, do: app_facing(:architecture)
  def quality_checks, do: app_facing(:quality)
  def dependencies_analysis, do: app_facing(:dependencies)
  def patterns_suggestions, do: app_facing(:patterns)
  def templates_suggestions, do: app_facing(:templates)
  def refactoring_suggestions, do: app_facing(:refactoring)

  def meta_registry_naming, do: meta(:naming)
  def meta_registry_architecture, do: meta(:architecture)
  def meta_registry_quality, do: meta(:quality)
  def meta_registry_dependencies, do: meta(:dependencies)
  def meta_registry_patterns, do: meta(:patterns)
  def meta_registry_templates, do: meta(:templates)
  def meta_registry_refactoring, do: meta(:refactoring)

  @doc """
  Detect tech stack and return appropriate subjects.

  ## Examples

      # For a PHP/Laravel app
      iex> NatsSubjects.for_tech_stack("php", "laravel")
      %{
        app_facing: %{naming: "naming.suggestions", ...},
        meta: %{naming: "analysis.meta.registry.naming", ...},
        usage: %{naming: "analysis.meta.usage.naming", ...}
      }
      
      # For a Node.js/Express app  
      iex> NatsSubjects.for_tech_stack("javascript", "express")
      %{
        app_facing: %{naming: "naming.suggestions", ...},
        meta: %{naming: "analysis.meta.registry.naming", ...},
        usage: %{naming: "analysis.meta.usage.naming", ...}
      }
  """
  def for_tech_stack(language, framework \\ nil) do
    # For now, all tech stacks use the same subjects
    # Later: could customize based on language/framework
    %{
      app_facing: @app_facing_subjects,
      meta: @meta_subjects,
      usage: @usage_subjects,
      detected_tech: %{
        language: language,
        framework: framework,
        detected_at: DateTime.utc_now()
      }
    }
  end
end
