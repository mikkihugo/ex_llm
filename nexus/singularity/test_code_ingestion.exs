# Test code ingestion to code_files table
Mix.install([
  {:ecto_sql, "~> 3.11"},
  {:postgrex, "~> 0.19"}
])

# Define schema
defmodule CodeFile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "code_files" do
    field :project_name, :string
    field :file_path, :string
    field :language, :string
    field :content, :string
    field :size_bytes, :integer
    field :line_count, :integer
    field :hash, :string
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(code_file, attrs) do
    code_file
    |> cast(attrs, [:project_name, :file_path, :language, :content, :size_bytes, :line_count, :hash, :metadata])
    |> validate_required([:project_name, :file_path])
    |> unique_constraint([:project_name, :file_path])
  end
end

# Define repo
defmodule TestRepo do
  use Ecto.Repo,
    otp_app: :test_app,
    adapter: Ecto.Adapters.Postgres
end

Application.put_env(:test_app, TestRepo,
  hostname: "localhost",
  socket_dir: "/home/mhugo/code/singularity/.dev-db/pg",
  database: "singularity",
  pool_size: 1
)

# Start repo
{:ok, _} = TestRepo.start_link()

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Testing Code Ingestion to code_files")
IO.puts(String.duplicate("=", 60) <> "\n")

# Test 1: Insert a test code file
IO.puts("1. Inserting test code file...")

test_code = """
defmodule TestModule do
  @moduledoc "Test module for ingestion"
  
  def hello(name) do
    "Hello, \#{name}!"
  end
end
"""

changeset = CodeFile.changeset(%CodeFile{}, %{
  project_name: "singularity",
  file_path: "lib/test/test_module.ex",
  language: "elixir",
  content: test_code,
  size_bytes: byte_size(test_code),
  line_count: length(String.split(test_code, "\n")),
  hash: :crypto.hash(:sha256, test_code) |> Base.encode16(case: :lower),
  metadata: %{
    functions: ["hello/1"],
    module_name: "TestModule"
  }
})

case TestRepo.insert(changeset, on_conflict: :replace_all, conflict_target: [:project_name, :file_path]) do
  {:ok, file} ->
    IO.puts("✓ Inserted: #{file.file_path}")
  {:error, changeset} ->
    IO.puts("✗ Error: #{inspect(changeset.errors)}")
end

# Test 2: Count total files
IO.puts("\n2. Counting code files...")
count = TestRepo.one!(Ecto.Query.from(c in "code_files", select: count(c.id)))
IO.puts("✓ Total code files: #{count}")

# Test 3: Query inserted file
IO.puts("\n3. Querying inserted file...")
files = TestRepo.all(Ecto.Query.from(c in CodeFile, where: c.project_name == "singularity"))
Enum.each(files, fn f ->
  IO.puts("  - #{f.file_path} (#{f.language}, #{f.line_count} lines)")
end)

# Test 4: Test FTS search
IO.puts("\n4. Testing full-text search...")
query = """
SELECT file_path, language, 
       ts_rank(search_vector, plainto_tsquery('english', $1)) as rank
FROM code_files
WHERE search_vector @@ plainto_tsquery('english', $1)
ORDER BY rank DESC
LIMIT 3
"""

case TestRepo.query(query, ["TestModule"]) do
  {:ok, result} ->
    IO.puts("✓ FTS search found #{result.num_rows} results:")
    Enum.each(result.rows, fn [path, lang, rank] ->
      IO.puts("  - #{path} (#{lang}) rank: #{Float.round(rank, 4)}")
    end)
  {:error, error} ->
    IO.puts("✗ FTS error: #{inspect(error)}")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Code Ingestion Test Complete!")
IO.puts(String.duplicate("=", 60) <> "\n")
