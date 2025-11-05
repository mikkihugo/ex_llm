defmodule SimpleFileTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag :file_management
  @moduletag timeout: 30_000

  test "direct provider call" do
    # Test if we can call the provider directly
    file_path = "/tmp/test.txt"
    File.write!(file_path, "Hello SingularityLLM")

    {:ok, file} = SingularityLLM.Providers.OpenAI.upload_file(file_path, "assistants")
    assert file["id"] =~ ~r/^file-/
    assert file["status"] == "processed"

    # Delete the uploaded file
    if file["id"] do
      SingularityLLM.Providers.OpenAI.delete_file(file["id"])
    end

    # Cleanup local file
    File.rm(file_path)
  end

  test "file manager call" do
    # Test the FileManager API
    file_path = "/tmp/test2.txt"
    File.write!(file_path, "Hello FileManager")

    {:ok, file} = SingularityLLM.FileManager.upload_file(:openai, file_path, purpose: "assistants")
    assert file["id"] =~ ~r/^file-/
    assert file["status"] == "processed"

    # Delete the uploaded file
    if file["id"] do
      SingularityLLM.FileManager.delete_file(:openai, file["id"])
    end

    # Cleanup local file
    File.rm(file_path)
  end
end
