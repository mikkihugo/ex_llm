defmodule Singularity.CodeIngestionService do
  @moduledoc """
  Code Ingestion Service - Coordinates parsing and storage of code into database
  
  This service orchestrates the flow:
  1. ParserEngine parses files/directories into AST
  2. CodeEngine analyzes the parsed code
  3. ArchitectureEngine provides naming suggestions
  4. Results are stored in the database
  
  ## Usage:
  
      # Parse and store a single file
      CodeIngestionService.ingest_file("src/app.ex")
      
      # Parse and store entire directory
      CodeIngestionService.ingest_directory("src/")
      
      # Parse and store with specific codebase ID
      CodeIngestionService.ingest_directory("src/", codebase_id: "my_project")
  """

  require Logger
  import Ecto.Query
  alias Singularity.{ParserEngine, CodeEngine, Repo}
  alias Singularity.Schemas.CodeFile

  @doc """
  Ingest a single file into the database
  """
  def ingest_file(file_path, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id, "default")
    
    Logger.info("Ingesting file: #{file_path}")
    
    with {:ok, document} <- ParserEngine.parse_file(file_path),
         {:ok, analysis} <- CodeEngine.analyze_code(file_path, document.language),
         {:ok, _} <- store_file_analysis(codebase_id, file_path, document, analysis) do
      Logger.info("Successfully ingested file: #{file_path}")
      {:ok, %{file: file_path, document: document, analysis: analysis}}
    else
      {:error, reason} ->
        Logger.error("Failed to ingest file #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ingest entire directory tree into the database
  """
  def ingest_directory(root_path, opts \\ []) do
    codebase_id = Keyword.get(opts, :codebase_id, "default")
    
    Logger.info("Ingesting directory: #{root_path}")
    
    with {:ok, documents} <- ParserEngine.parse_tree(root_path),
         {:ok, results} <- process_documents(codebase_id, documents) do
      Logger.info("Successfully ingested #{length(documents)} files from #{root_path}")
      {:ok, results}
    else
      {:error, reason} ->
        Logger.error("Failed to ingest directory #{root_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get codebase analysis summary
  """
  def get_codebase_summary(codebase_id) do
    with {:ok, files} <- get_codebase_files(codebase_id),
         {:ok, analysis} <- CodeEngine.analyze_code(codebase_id, "auto") do
      {:ok, %{
        codebase_id: codebase_id,
        file_count: length(files),
        files: files,
        analysis: analysis
      }}
    end
  end

  # Private functions

  defp process_documents(codebase_id, documents) do
    results = 
      documents
      |> Task.async_stream(&process_single_document(codebase_id, &1), max_concurrency: 10)
      |> Enum.map(fn {:ok, result} -> result end)
    
    {:ok, results}
  end

  defp process_single_document(codebase_id, document) do
    file_path = document.path
    
    with {:ok, analysis} <- CodeEngine.analyze_code(file_path, document.language),
         {:ok, _} <- store_file_analysis(codebase_id, file_path, document, analysis) do
      {:ok, %{file: file_path, status: :success}}
    else
      {:error, reason} ->
        Logger.warning("Failed to process #{file_path}: #{inspect(reason)}")
        {:ok, %{file: file_path, status: :failed, error: reason}}
    end
  end

  defp store_file_analysis(codebase_id, file_path, document, analysis) do
    content =
      Map.get(document, :content) ||
        Map.get(document, "content") ||
        case File.read(file_path) do
          {:ok, data} -> data
          _ -> ""
        end

    ast = Map.get(document, :ast) || Map.get(document, "ast") || %{}
    functions = Map.get(document, :functions) || Map.get(document, "functions") || []
    classes = Map.get(document, :classes) || Map.get(document, "classes") || []
    imports = Map.get(document, :imports) || Map.get(document, "imports") || []
    exports = Map.get(document, :exports) || Map.get(document, "exports") || []
    language = Map.get(document, :language) || Map.get(document, "language")

    metadata =
      case analysis do
        %{metadata: value} when is_map(value) -> value
        _ -> %{}
      end

    file_size = byte_size(content)
    line_count = if content == "", do: 0, else: String.split(content, "\n", trim: false) |> length()

    attrs = %{
      codebase_id: codebase_id,
      file_path: file_path,
      language: language,
      content: content,
      file_size: file_size,
      line_count: line_count,
      hash: :crypto.hash(:md5, content) |> Base.encode16(),
      ast_json: ast,
      functions: functions,
      classes: classes,
      imports: imports,
      exports: exports,
      metadata: metadata,
      parsed_at: DateTime.utc_now()
    }

    case Repo.insert(CodeFile.changeset(%CodeFile{}, attrs)) do
      {:ok, _} -> {:ok, :stored}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp get_codebase_files(codebase_id) do
    query =
      from f in CodeFile,
        where: f.codebase_id == ^codebase_id,
        select: %{path: f.file_path, language: f.language, size: f.file_size}

    {:ok, Repo.all(query)}
  end
end
