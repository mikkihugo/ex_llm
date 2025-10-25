defmodule Singularity.Knowledge.TemplateGeneration do
  @moduledoc """
  Template Generation Tracking - Track what templates generated what code.

  Inspired by Copier's .copier-answers.yml pattern, adapted for Learning Knowledge Base.

  ## Answer File Pattern

  When a template generates code, we record:

  ```elixir
  %TemplateGeneration{
    template_id: "quality_template:elixir-production",
    template_version: "2.1.0",
    file_path: "lib/singularity/my_module.ex",
    answers: %{
      "language" => "elixir",
      "quality_level" => "production",
      "include_tests" => true
    },
    generated_at: ~U[2025-01-10 12:00:00Z],
    success: true
  }
  ```

  ## Benefits

  1. **Learning**: Track which templates work well
  2. **Debugging**: "Why was this code generated?"
  3. **Updates**: When template evolves, regenerate code
  4. **Analytics**: Template usage patterns

  ## Usage

  ```elixir
  # After generating code
  TemplateGeneration.record(
    template_id: "quality_template:elixir-genserver",
    template_version: "2.1.0",
    file_path: "lib/my_app/worker.ex",
    answers: %{"otp_type" => "GenServer", "supervision" => true}
  )

  # Find what template generated a file
  {:ok, gen} = TemplateGeneration.find_by_file("lib/my_app/worker.ex")
  gen.template_id  # => "quality_template:elixir-genserver"

  # Get all generations from a template
  gens = TemplateGeneration.list_by_template("quality_template:elixir-genserver")
  success_rate = calculate_success_rate(gens)

  # Auto-update when template evolves
  TemplateGeneration.regenerate_from_template(
    "quality_template:elixir-genserver",
    from_version: "2.0.0",
    to_version: "2.1.0"
  )
  ```

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Knowledge.TemplateGeneration",
    "purpose": "Track template-based code generation with Copier-inspired answer files",
    "role": "knowledge_service",
    "layer": "domain_services",
    "key_responsibilities": [
      "Record template-generated code with answers",
      "Track template version history and evolution",
      "Provide generation analytics and success rates",
      "Support auto-regeneration when templates evolve"
    ],
    "prevents_duplicates": ["CodeGenerator", "TemplateOrchestrator", "GenerationTracker"],
    "uses": ["Repo", "LLM.Service", "File", "Logger"]
  }
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Repo
      function: insert/1, update/1, query/1
      purpose: Store/retrieve generation records
      critical: true

    - module: Singularity.LLM.Service
      function: call/3, call_with_prompt/3
      purpose: Optional AI enhancement of generated code
      critical: false

    - module: File
      function: write/2, read/2
      purpose: Write generated code to disk
      critical: true

    - module: Logger
      function: info/2, warn/2
      purpose: Log generation events and errors
      critical: false

  called_by:
    - module: Singularity.Knowledge.TemplateService
      function: apply_template/2
      purpose: Record generation results after template application
      frequency: per_template_use

    - module: Singularity.Agents.SelfImprovingAgent
      function: improve_code/1
      purpose: Track AI-enhanced code generation
      frequency: per_improvement

    - module: Singularity.CodeGeneration.RAGCodeGenerator
      function: generate/1
      purpose: Track RAG-generated code with template source
      frequency: per_generation

  state_transitions:
    - name: record
      from: idle
      to: idle
      increments: generation_count, success_count (if success: true)
      updates: last_generated timestamp

    - name: regenerate_from_template
      from: idle
      to: idle
      actions:
        - Find all generations from old template version
        - Re-apply template with new version
        - Update generation records
        - Log regeneration events

  depends_on:
    - PostgreSQL database (MUST be available)
    - Singularity.Repo (MUST be functional)
    - File system write access (MUST be available)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create TemplateOrchestrator or CodeGenerator duplicates
  **Why:** TemplateGeneration is the single source of truth for template-based code generation.
  ```elixir
  # ❌ WRONG - Duplicate module
  defmodule MyApp.TemplateOrchestrator do
    def apply_and_track(template_id, answers) do
      # Re-implementing what TemplateGeneration does
    end
  end

  # ✅ CORRECT - Use TemplateGeneration
  TemplateGeneration.record(template_id, file_path, answers)
  ```

  #### ❌ DO NOT bypass generation tracking for "obvious" templates
  **Why:** All generations must be tracked for analytics and learning loop.
  ```elixir
  # ❌ WRONG - Skip tracking for "simple" templates
  if is_complex_template(template), do: TemplateGeneration.record(...)

  # ✅ CORRECT - Always track, regardless of complexity
  TemplateGeneration.record(template_id, file_path, answers)
  ```

  #### ❌ DO NOT hardcode template answers
  **Why:** Answers must be parameterized for different contexts.
  ```elixir
  # ❌ WRONG - Hardcoded answers
  answers = %{"language" => "elixir", "quality_level" => "production"}

  # ✅ CORRECT - Parameterized from context
  answers = build_answers_from_context(template_id, context)
  TemplateGeneration.record(template_id, file_path, answers)
  ```

  #### ❌ DO NOT regenerate without version tracking
  **Why:** Version history is critical for tracking template evolution.
  ```elixir
  # ❌ WRONG - Ignore template version changes
  TemplateGeneration.regenerate_from_template(template_id)

  # ✅ CORRECT - Track version changes explicitly
  TemplateGeneration.regenerate_from_template(
    template_id,
    from_version: "2.0.0",
    to_version: "2.1.0"
  )
  ```

  ### Search Keywords

  template generation, code generation from templates, Copier pattern, template answers,
  template tracking, template versioning, generation analytics, template evolution,
  code generation tracking, template-based code, template performance, generation history,
  answer files, template application, generation success rate, template usage patterns
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Knowledge.ArtifactStore

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "template_generations" do
    field :template_id, :string
    field :template_version, :string
    field :file_path, :string
    field :answers, :map
    field :generated_at, :utc_datetime
    field :success, :boolean, default: true
    field :error_message, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Record a template generation with automatic answer file writing and CentralCloud publishing.
  """
  def record(attrs) do
    changeset = %__MODULE__{} |> changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, generation} = result ->
        # Phase 2: Automatically write .template-answers.yml file
        write_answer_file(generation)

        # Phase 3: Publish to CentralCloud for cross-instance intelligence
        publish_to_centralcloud(generation)

        result

      error ->
        error
    end
  end

  @doc """
  Find generation record by file path.
  """
  def find_by_file(file_path) do
    __MODULE__
    |> where([g], g.file_path == ^file_path)
    |> order_by([g], desc: g.generated_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      gen -> {:ok, gen}
    end
  end

  @doc """
  List all generations from a template.
  """
  def list_by_template(template_id) do
    __MODULE__
    |> where([g], g.template_id == ^template_id)
    |> order_by([g], desc: g.generated_at)
    |> Repo.all()
  end

  @doc """
  Calculate success rate for a template.
  """
  def calculate_success_rate(template_id) when is_binary(template_id) do
    template_id
    |> list_by_template()
    |> calculate_success_rate()
  end

  def calculate_success_rate(generations) when is_list(generations) do
    total = length(generations)

    if total == 0 do
      0.0
    else
      successful = Enum.count(generations, & &1.success)
      successful / total
    end
  end

  @doc """
  Regenerate code from evolved template.

  Finds all files generated by old template version and regenerates with new version.
  """
  def regenerate_from_template(template_id, opts \\ []) do
    from_version = Keyword.get(opts, :from_version)
    to_version = Keyword.get(opts, :to_version)

    query =
      __MODULE__
      |> where([g], g.template_id == ^template_id)

    query =
      if from_version do
        where(query, [g], g.template_version == ^from_version)
      else
        query
      end

    generations = Repo.all(query)

    {:ok, template} = ArtifactStore.get_by_identifier(template_id)

    Enum.map(generations, fn gen ->
      # TODO: Regenerate code with new template + migration scripts
      regenerate_file(gen, template, to_version)
    end)
  end

  # Private

  defp changeset(generation, attrs) do
    generation
    |> cast(attrs, [
      :template_id,
      :template_version,
      :file_path,
      :answers,
      :generated_at,
      :success,
      :error_message
    ])
    |> validate_required([:template_id, :file_path, :answers])
    |> put_change(:generated_at, DateTime.utc_now())
  end

  defp regenerate_file(generation, template, new_version) do
    # TODO:
    # 1. Load template migrations from old version to new
    # 2. Run "before" migration scripts
    # 3. Regenerate code with new template
    # 4. Run "after" migration scripts
    # 5. Record new generation

    {:ok, generation}
  end

  @doc """
  Export answer file (like .copier-answers.yml) for a file.

  Useful for debugging and understanding code generation history.
  """
  def export_answer_file(file_path) do
    case find_by_file(file_path) do
      {:ok, gen} ->
        answer_file = %{
          "_template_id" => gen.template_id,
          "_template_version" => gen.template_version,
          "_generated_at" => gen.generated_at,
          "_success" => gen.success
        }

        answer_file = Map.merge(answer_file, gen.answers)

        {:ok, YamlElixir.encode(answer_file)}

      error ->
        error
    end
  end

  @doc """
  Write .template-answers.yml file next to generated file.

  This creates a git-trackable answer file for manual inspection,
  regeneration, and template upgrade workflows.
  """
  def write_answer_file(%__MODULE__{} = generation) do
    require Logger

    if generation.file_path do
      answer_file_path = generation.file_path <> ".template-answers.yml"

      # Generate YAML content
      yaml_content = format_answer_file_yaml(generation)

      case File.write(answer_file_path, yaml_content) do
        :ok ->
          Logger.debug("Wrote answer file: #{answer_file_path}")
          {:ok, answer_file_path}

        {:error, reason} ->
          Logger.warning("Failed to write answer file: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:ok, :no_file_path}
    end
  end

  defp format_answer_file_yaml(generation) do
    # Format as simple YAML (without external dependencies)
    generated_at =
      if generation.generated_at do
        DateTime.to_iso8601(generation.generated_at)
      else
        DateTime.to_iso8601(DateTime.utc_now())
      end

    header = """
    # Template Answer File
    # Generated by Singularity - Tracks code generation for upgrades and learning
    # To regenerate: mix template.regenerate #{generation.file_path}

    _template_id: #{generation.template_id}
    _template_version: #{generation.template_version}
    _generated_at: #{generated_at}
    _success: #{generation.success}

    # Answers provided during generation:
    """

    # Format answers as YAML
    answers_yaml =
      generation.answers
      |> Enum.map(fn {key, value} ->
        "#{key}: #{format_yaml_value(value)}"
      end)
      |> Enum.join("\n")

    header <> answers_yaml <> "\n"
  end

  defp format_yaml_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_yaml_value(value) when is_boolean(value), do: to_string(value)
  defp format_yaml_value(value) when is_number(value), do: to_string(value)
  defp format_yaml_value(value) when is_atom(value), do: ":#{value}"
  defp format_yaml_value(value), do: inspect(value)

  @doc """
  Publish generation to CentralCloud for cross-instance intelligence gathering.

  Phase 3: Enables collective learning across all Singularity instances.
  CentralCloud aggregates patterns like:
  - "72% of instances use ETS with GenServer"
  - "GenServer + ETS + one_for_one = 98% success rate"
  """
  def publish_to_centralcloud(%__MODULE__{} = generation) do
    require Logger

    # Build message for CentralCloud
    message = %{
      template_id: generation.template_id,
      template_version: generation.template_version,
      answers: generation.answers,
      success: generation.success,
      quality_score: get_in(generation.answers, ["quality_score"]),
      generated_at:
        if(generation.generated_at,
          do: DateTime.to_iso8601(generation.generated_at),
          else: DateTime.to_iso8601(DateTime.utc_now())
        ),
      # Which Singularity instance
      instance_id: node() |> to_string(),
      # Strip user/project paths
      file_path: anonymize_path(generation.file_path)
    }

    # Publish to CentralCloud via NATS
    case Singularity.NATS.Client.publish("centralcloud.template.generation", message) do
      :ok ->
        Logger.debug("Published generation to CentralCloud: #{generation.template_id}")
        :ok

      {:error, reason} ->
        # Don't fail the whole operation if NATS is down
        Logger.warning("Failed to publish to CentralCloud: #{inspect(reason)}")
        :ok
    end
  rescue
    e ->
      Logger.warning("Exception publishing to CentralCloud: #{inspect(e)}")
      :ok
  end

  # Anonymize file paths for privacy
  defp anonymize_path(nil), do: nil

  defp anonymize_path(path) when is_binary(path) do
    # Keep only relative path from project root
    # /Users/alice/secret-project/lib/auth.ex -> lib/auth.ex
    case String.split(path, "/lib/") do
      [_prefix, relative] ->
        "lib/" <> relative

      _ ->
        case String.split(path, "/test/") do
          [_prefix, relative] -> "test/" <> relative
          # Just filename if can't parse
          _ -> Path.basename(path)
        end
    end
  end
end
