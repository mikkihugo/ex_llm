defmodule Singularity.CodeModelTest do
  use ExUnit.Case, async: true

  alias Singularity.CodeModel
  alias Ecto.UUID

  @telemetry_events [
    [:singularity, :code_generator, :generate, :start],
    [:singularity, :code_generator, :generate, :stop],
    [:singularity, :code_generator, :generate, :exception]
  ]

  test "complete emits telemetry span" do
    handler_id = "code-generator-telemetry-test-" <> UUID.generate()
    parent = self()

    :telemetry.attach_many(handler_id, @telemetry_events, fn event, measurements, metadata, _ ->
      send(parent, {:telemetry, event, measurements, metadata})
    end, nil)

    on_exit(fn -> :telemetry.detach(handler_id) rescue _ -> :ok end)

    _ = CodeModel.complete("defmodule Demo do\nend\n", temperature: 0.1, max_tokens: 1)

    assert_receive {:telemetry, [:singularity, :code_generator, :generate, :start], _measurements,
                     %{operation: :complete, prompt_chars: prompt_chars}}, 100

    assert is_integer(prompt_chars)

    assert_receive {:telemetry, [:singularity, :code_generator, :generate, :stop], measurements,
                     %{operation: :complete, status: status, model: _model}}, 100

    assert is_integer(measurements.duration)
    assert status in [:ok, :error]
  end
end
