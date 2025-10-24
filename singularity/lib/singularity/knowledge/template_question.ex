defmodule Singularity.Knowledge.TemplateQuestion do
  @moduledoc """
  Template Question - Interactive questionnaire for AI-driven code generation.

  Inspired by Copier's question system, adapted for LLM-based workflows using Solid (Handlebars).

  ## Schema (JSON in knowledge_artifacts)

  ```json
  {
    "type": "quality_template",
    "content": {
      "questions": [
        {
          "var_name": "test_framework",
          "type": "str",
          "help": "Which test framework?",
          "choices": ["ExUnit", "Wallaby", "Hound"],
          "default": "ExUnit",
          "validator": "{{#if (eq test_framework '')}}Required!{{/if}}",
          "when": "{{include_tests}}"
        }
      ]
    }
  }
  ```

  ## Question Types

  - `str` - String input
  - `int` - Integer
  - `float` - Float
  - `bool` - Boolean (yes/no)
  - `yaml` - YAML-parsed value
  - `json` - JSON-parsed value

  ## Features

  - **Dynamic choices**: Choices based on previous answers
  - **Validators**: Jinja templates that render error message if invalid
  - **Conditional questions**: `when` clause to skip questions
  - **Multiselect**: Multiple choice selection
  - **Secret**: Hide from answer file (passwords, API keys)

  ## Usage with LLM

  ```elixir
  # Get template with questions
  {:ok, template} = ArtifactStore.get("quality_template", "elixir-production")

  # Ask questions via LLM
  answers = TemplateQuestion.ask_via_llm(template.content["questions"])

  # Generate code with answers
  code = QualityCodeGenerator.generate(template, answers)

  # Track what was generated
  ArtifactStore.record_generation(template.id, answers, code)
  ```
  """

  alias Singularity.LLM.Service

  @type question :: %{
          var_name: String.t(),
          type: String.t(),
          help: String.t(),
          choices: list() | nil,
          default: any(),
          validator: String.t() | nil,
          when: boolean() | String.t(),
          multiselect: boolean(),
          secret: boolean()
        }

  @type answers :: %{String.t() => any()}

  @doc """
  Ask questions via LLM interaction.

  Phase 3: Now queries CentralCloud for smart defaults based on global usage patterns!

  Uses LLM to intelligently gather answers based on context, with defaults
  informed by cross-instance learning from CentralCloud.
  """
  @spec ask_via_llm(list(question()), keyword()) :: {:ok, answers()} | {:error, term()}
  def ask_via_llm(questions, opts \\ []) do
    context = Keyword.get(opts, :context, %{})
    template_id = Keyword.get(opts, :template_id)

    # Phase 3: Get smart defaults from CentralCloud
    smart_defaults = get_smart_defaults_from_centralcloud(template_id, questions)

    # Merge smart defaults with template defaults
    questions_with_smart_defaults = apply_smart_defaults(questions, smart_defaults)

    prompt = build_questionnaire_prompt(questions_with_smart_defaults, context, smart_defaults)

    case Service.call_with_prompt(:simple, prompt, task_type: :classifier) do
      {:ok, response} ->
        answers = parse_llm_answers(response, questions_with_smart_defaults)
        validate_answers(answers, questions_with_smart_defaults)

      error ->
        error
    end
  end

  @doc """
  Validate answers against question validators.
  """
  @spec validate_answers(answers(), list(question())) :: {:ok, answers()} | {:error, term()}
  def validate_answers(answers, questions) do
    Enum.reduce_while(questions, {:ok, answers}, fn question, {:ok, acc} ->
      case validate_answer(answers[question.var_name], question, answers) do
        :ok -> {:cont, {:ok, acc}}
        {:error, reason} -> {:halt, {:error, {question.var_name, reason}}}
      end
    end)
  end

  @doc """
  Validate a single answer.
  """
  @spec validate_answer(any(), question(), answers()) :: :ok | {:error, String.t()}
  def validate_answer(answer, question, all_answers) do
    # Type validation
    with :ok <- validate_type(answer, question.type),
         :ok <- validate_custom(answer, question.validator, all_answers) do
      :ok
    end
  end

  # Private

  defp build_questionnaire_prompt(questions, context) do
    visible_questions =
      questions
      |> Enum.filter(&should_ask?(&1, context))
      |> Enum.map(&format_question/1)
      |> Enum.join("\n\n")

    """
    Please answer the following questions about the code to generate:

    #{visible_questions}

    Respond with a JSON object containing your answers.
    Example: {"var_name": "value", "another_var": "value2"}
    """
  end

  defp should_ask?(question, context) do
    case question[:when] do
      nil -> true
      true -> true
      false -> false
      condition when is_binary(condition) -> evaluate_condition(condition, context)
    end
  end

  defp format_question(question) do
    help = if question[:help], do: " - #{question[:help]}", else: ""
    type_hint = "(#{question[:type]})"

    choices =
      if question[:choices] do
        "\nChoices: #{inspect(question[:choices])}"
      else
        ""
      end

    default =
      if question[:default] do
        "\nDefault: #{inspect(question[:default])}"
      else
        ""
      end

    """
    #{question.var_name} #{type_hint}#{help}#{choices}#{default}
    """
  end

  defp parse_llm_answers(response, _questions) do
    # Parse JSON response from LLM
    case Jason.decode(response) do
      {:ok, answers} -> answers
      _ -> %{}
    end
  end

  defp validate_type(answer, type) do
    case {type, answer} do
      {"str", value} when is_binary(value) -> :ok
      {"int", value} when is_integer(value) -> :ok
      {"float", value} when is_float(value) -> :ok
      {"bool", value} when is_boolean(value) -> :ok
      {"yaml", _} -> :ok
      {"json", _} -> :ok
      _ -> {:error, "Type mismatch: expected #{type}, got #{inspect(answer)}"}
    end
  end

  defp validate_custom(_answer, nil, _all_answers), do: :ok
  defp validate_custom(_answer, "", _all_answers), do: :ok

  defp validate_custom(answer, validator_template, all_answers) do
    # Render Solid (Handlebars) validator template with answer
    context = Map.put(all_answers, :answer, answer)

    case render_solid(validator_template, context) do
      {:ok, ""} -> :ok
      {:ok, error_message} -> {:error, error_message}
      {:error, _} = error -> error
    end
  end

  defp evaluate_condition(condition, context) do
    case render_solid(condition, context) do
      {:ok, result} -> truthy?(result)
      {:error, _} -> false
    end
  end

  defp render_solid(template, context) when is_binary(template) do
    # Use Solid (Handlebars) engine for template rendering
    case Solid.parse(template) do
      {:ok, parsed} ->
        case Solid.render(parsed, context) do
          {:ok, iodata} -> {:ok, IO.iodata_to_binary(iodata)}
          error -> error
        end

      error ->
        error
    end
  end

  defp truthy?(value) when is_binary(value) do
    String.downcase(value) in ["true", "yes", "1", "y"]
  end

  defp truthy?(value), do: !!value

  # Phase 3: CentralCloud Intelligence Integration

  defp get_smart_defaults_from_centralcloud(nil, _questions), do: %{}
  defp get_smart_defaults_from_centralcloud(template_id, _questions) do
    require Logger

    # Query CentralCloud for smart defaults via NATS
    message = %{
      action: "suggest_defaults",
      template_id: template_id
    }

    case Singularity.NatsClient.request("centralcloud.template.intelligence", message, timeout: 2000) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, %{"suggested_answers" => defaults, "confidence" => confidence, "sample_size" => sample_size}} ->
            Logger.info("Got smart defaults from CentralCloud (#{sample_size} samples, #{Float.round(confidence * 100, 1)}% confidence)")
            defaults

          {:ok, _other} ->
            Logger.debug("No smart defaults available from CentralCloud")
            %{}

          {:error, reason} ->
            Logger.warning("Failed to parse CentralCloud response: #{inspect(reason)}")
            %{}
        end

      {:error, reason} ->
        Logger.debug("CentralCloud not available: #{inspect(reason)}")
        %{}
    end
  rescue
    e ->
      Logger.debug("Exception querying CentralCloud: #{inspect(e)}")
      %{}
  end

  defp apply_smart_defaults(questions, smart_defaults) when smart_defaults == %{}, do: questions
  defp apply_smart_defaults(questions, smart_defaults) do
    Enum.map(questions, fn question ->
      question_name = question["name"] || question[:name]

      case Map.get(smart_defaults, question_name) do
        nil ->
          question

        smart_default_data when is_map(smart_default_data) ->
          # CentralCloud returns {value => count} maps, take most common
          {most_common_value, _count} = Enum.max_by(smart_default_data, fn {_val, count} -> count end)

          # Update question default with smart default
          Map.put(question, "default", most_common_value)
          |> Map.put("smart_default", true)
          |> Map.put("smart_default_usage", Map.values(smart_default_data) |> Enum.sum())

        smart_default_value ->
          # Direct value
          Map.put(question, "default", smart_default_value)
          |> Map.put("smart_default", true)
      end
    end)
  end

  defp build_questionnaire_prompt(questions, context) do
    build_questionnaire_prompt(questions, context, %{})
  end

  defp build_questionnaire_prompt(questions, context, smart_defaults) do
    visible_questions =
      questions
      |> Enum.filter(&should_ask?(&1, context))
      |> Enum.map(&format_question_with_intelligence/1)
      |> Enum.join("\n\n")

    intelligence_note = if map_size(smart_defaults) > 0 do
      sample_size = smart_defaults |> Map.values() |> List.first() |> Map.get("sample_size", 0)
      """

      Note: Default values below are informed by #{sample_size} generations across multiple instances.
      """
    else
      ""
    end

    """
    Please answer the following questions about the code to generate:

    #{visible_questions}#{intelligence_note}

    Respond with a JSON object containing your answers.
    Example: {"var_name": "value", "another_var": "value2"}
    """
  end

  defp format_question_with_intelligence(question) do
    base = format_question(question)

    smart_note = if Map.get(question, "smart_default") do
      usage = Map.get(question, "smart_default_usage", 0)
      "\n  (Based on #{usage} instances)"
    else
      ""
    end

    base <> smart_note
  end
end
