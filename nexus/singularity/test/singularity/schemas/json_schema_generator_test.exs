defmodule Singularity.Schemas.EctoSchemaToJsonSchemaGeneratorTest do
  use ExUnit.Case

  alias Singularity.Schemas.EctoSchemaToJsonSchemaGenerator, as: Generator

  defmodule TestSchema do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:name, :string)
      field(:age, :integer)
      field(:active, :boolean)
      field(:score, :float)
      field(:tags, {:array, :string})
      field(:metadata, :map)
    end
  end

  describe "generate/1" do
    test "generates JSON Schema for simple schema" do
      schema = Generator.generate([TestSchema])

      assert schema["$schema"] == "http://json-schema.org/draft-07/schema#"

      # Module name is converted to underscore format
      module_name = "Singularity_Schemas_EctoSchemaToJsonSchemaGeneratorTest_TestSchema"
      assert Map.has_key?(schema["definitions"], module_name)

      test_schema = schema["definitions"][module_name]

      assert test_schema["type"] == "object"
      assert test_schema["properties"]["name"]["type"] == "string"
      assert test_schema["properties"]["age"]["type"] == "integer"
      assert test_schema["properties"]["active"]["type"] == "boolean"
      assert test_schema["properties"]["score"]["type"] == "number"
      assert test_schema["properties"]["tags"]["type"] == "array"
      assert test_schema["properties"]["metadata"]["type"] == "object"
    end

    test "includes required fields" do
      schema = Generator.generate([TestSchema])
      module_name = "Singularity_Schemas_EctoSchemaToJsonSchemaGeneratorTest_TestSchema"
      test_schema = schema["definitions"][module_name]

      assert "name" in test_schema["required"]
      assert "age" in test_schema["required"]
    end
  end

  describe "require_list_of/2" do
    test "validates top-level array" do
      base_schema = Generator.generate([TestSchema])
      array_schema = Generator.require_list_of(base_schema, TestSchema)

      assert array_schema["type"] == "array"
      # Module name is converted to underscore format
      expected_ref =
        "#/definitions/Singularity_Schemas_EctoSchemaToJsonSchemaGeneratorTest_TestSchema"

      assert array_schema["items"]["$ref"] == expected_ref
    end
  end
end
