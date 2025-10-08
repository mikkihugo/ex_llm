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
    naming: "naming.suggestions",
    architecture: "architecture.patterns", 
    quality: "quality.checks",
    dependencies: "dependencies.analysis",
    patterns: "patterns.suggestions",
    templates: "templates.suggestions",
    refactoring: "refactoring.suggestions"
  }

  # Internal meta-registry subjects (what OUR SYSTEM uses)
  @meta_subjects %{
    naming: "meta.registry.naming",
    architecture: "meta.registry.architecture",
    quality: "meta.registry.quality", 
    dependencies: "meta.registry.dependencies",
    patterns: "meta.registry.patterns",
    templates: "meta.registry.templates",
    refactoring: "meta.registry.refactoring"
  }

  # Usage tracking subjects
  @usage_subjects %{
    naming: "meta.usage.naming",
    architecture: "meta.usage.architecture",
    quality: "meta.usage.quality",
    dependencies: "meta.usage.dependencies",
    patterns: "meta.usage.patterns",
    templates: "meta.usage.templates",
    refactoring: "meta.usage.refactoring"
  }

  @doc """
  Get app-facing subject for a given category.
  
  ## Examples
  
      iex> NatsSubjects.app_facing(:naming)
      "naming.suggestions"
      
      iex> NatsSubjects.app_facing(:architecture)
      "architecture.patterns"
  """
  def app_facing(category) when is_atom(category) do
    Map.get(@app_facing_subjects, category, "unknown.suggestions")
  end

  @doc """
  Get internal meta-registry subject for a given category.
  
  ## Examples
  
      iex> NatsSubjects.meta(:naming)
      "meta.registry.naming"
      
      iex> NatsSubjects.meta(:architecture)
      "meta.registry.architecture"
  """
  def meta(category) when is_atom(category) do
    Map.get(@meta_subjects, category, "meta.registry.unknown")
  end

  @doc """
  Get usage tracking subject for a given category.
  
  ## Examples
  
      iex> NatsSubjects.usage(:naming)
      "meta.usage.naming"
      
      iex> NatsSubjects.usage(:architecture)
      "meta.usage.architecture"
  """
  def usage(category) when is_atom(category) do
    Map.get(@usage_subjects, category, "meta.usage.unknown")
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
  Detect tech stack and return appropriate subjects.
  
  ## Examples
  
      # For a PHP/Laravel app
      iex> NatsSubjects.for_tech_stack("php", "laravel")
      %{
        app_facing: %{naming: "naming.suggestions", ...},
        meta: %{naming: "meta.registry.naming", ...},
        usage: %{naming: "meta.usage.naming", ...}
      }
      
      # For a Node.js/Express app  
      iex> NatsSubjects.for_tech_stack("javascript", "express")
      %{
        app_facing: %{naming: "naming.suggestions", ...},
        meta: %{naming: "meta.registry.naming", ...},
        usage: %{naming: "meta.usage.naming", ...}
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