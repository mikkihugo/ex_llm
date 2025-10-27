defmodule Singularity.Tools.FileSystem do
  @moduledoc """
  File system tools for agents.

  Essential tools for reading, writing, and managing files.
  Provides safe file operations with proper error handling.

  ## Safety Features

  - Read-only by default for safety
  - Write operations include confirmation prompts
  - Path validation (no absolute paths outside codebase)
  - File size limits for reading
  - Backup before overwriting

  ## Tools

  - `file_read` - Read file contents
  - `file_write` - Write to file (safe)
  - `file_list` - List files in directory
  - `file_search` - Find files by pattern
  - `file_stats` - Get file metadata
  - `file_exists` - Check if file exists
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool
  alias Singularity.HITL.ApprovalService
  require Logger

  # 10MB max file size
  @max_read_size 10_000_000
  @allowed_extensions ~w(.ex .exs .eex .leex .heex .js .ts .tsx .jsx .json .md .yaml .yml .toml .txt .sql .sh .rs .go .py .rb .java .kt)

  @doc "Register file system tools with the shared registry."
  def register(provider) do
    Catalog.add_tools(provider, [
      file_read_tool(),
      file_write_tool(),
      file_list_tool(),
      file_search_tool(),
      file_stats_tool(),
      file_exists_tool()
    ])
  end

  # ============================================================================
  # TOOL DEFINITIONS
  # ============================================================================

  defp file_read_tool do
    Tool.new!(%{
      name: "file_read",
      description: "Read contents of a file. Returns file content as string.",
      display_text: "Read File",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: true,
          description: "Relative file path"
        },
        %{
          name: "lines",
          type: :integer,
          required: false,
          description: "Max lines to read (default: all)"
        }
      ],
      function: &file_read/2
    })
  end

  defp file_write_tool do
    Tool.new!(%{
      name: "file_write",
      description:
        "Write content to a file. Creates file if it doesn't exist. Backs up existing files.",
      display_text: "Write File",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: true,
          description: "Relative file path"
        },
        %{
          name: "content",
          type: :string,
          required: true,
          description: "Text content to write"
        },
        %{
          name: "mode",
          type: :string,
          required: false,
          description: "'overwrite' (default) or 'append'"
        }
      ],
      function: &file_write/2
    })
  end

  defp file_list_tool do
    Tool.new!(%{
      name: "file_list",
      description: "List files in a directory. Returns file names and basic info.",
      display_text: "List Files",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Relative directory path (default '.')"
        },
        %{
          name: "recursive",
          type: :boolean,
          required: false,
          description: "Recursively list subdirectories (default: false)"
        },
        %{
          name: "pattern",
          type: :string,
          required: false,
          description: "Filter by glob pattern (e.g., '*.ex')"
        }
      ],
      function: &file_list/2
    })
  end

  defp file_search_tool do
    Tool.new!(%{
      name: "file_search",
      description: "Find files by name pattern. Searches recursively from given path.",
      display_text: "Search Files",
      parameters: [
        %{
          name: "pattern",
          type: :string,
          required: true,
          description: "File name pattern (glob, e.g., '*.ex')"
        },
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Starting directory (default '.')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Max results (default: 50)"
        }
      ],
      function: &file_search/2
    })
  end

  defp file_stats_tool do
    Tool.new!(%{
      name: "file_stats",
      description: "Get file metadata (size, modified time, permissions).",
      display_text: "File Stats",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: true,
          description: "Relative file path"
        }
      ],
      function: &file_stats/2
    })
  end

  defp file_exists_tool do
    Tool.new!(%{
      name: "file_exists",
      description: "Check if a file or directory exists.",
      display_text: "File Exists",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: true,
          description: "Relative file path"
        }
      ],
      function: &file_exists/2
    })
  end

  # ============================================================================
  # TOOL IMPLEMENTATIONS
  # ============================================================================

  def file_read(%{"path" => path} = args, _ctx) do
    with {:ok, safe_path} <- validate_path(path),
         {:ok, file_info} <- File.stat(safe_path),
         :ok <- check_file_size(file_info.size),
         {:ok, content} <- File.read(safe_path) do
      # Optionally limit lines
      final_content =
        case Map.get(args, "lines") do
          nil ->
            content

          max_lines when is_integer(max_lines) ->
            content
            |> String.split("\n")
            |> Enum.take(max_lines)
            |> Enum.join("\n")
        end

      {:ok,
       %{
         path: path,
         content: final_content,
         size: byte_size(final_content),
         total_size: file_info.size,
         lines: length(String.split(final_content, "\n"))
       }}
    else
      {:error, :enoent} -> {:error, "File not found: #{path}"}
      {:error, :file_too_large} -> {:error, "File too large (max #{@max_read_size} bytes)"}
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  def file_write(%{"path" => path, "content" => content} = args, ctx) do
    mode = Map.get(args, "mode", "overwrite")
    description = Map.get(args, "description", "Write file: #{path}")

    with {:ok, safe_path} <- validate_path(path),
         :ok <- validate_extension(safe_path) do
      # Generate diff for approval
      existing_content = File.read(safe_path) |> elem(1) || ""
      diff = generate_diff(existing_content, content, path)

      # Request approval (blocks until user clicks Google Chat button)
      {:ok, approval_id} =
        ApprovalService.request_approval(
          file_path: path,
          diff: diff,
          description: description,
          agent_id: Map.get(ctx, :agent_id, "unknown")
        )

      # Wait for decision (BLOCKS HERE until approved/rejected)
      case ApprovalService.wait_for_decision(approval_id) do
        {:ok, :approved} ->
          # User approved, proceed with write
          with :ok <- maybe_backup_file(safe_path, mode),
               :ok <- write_file(safe_path, content, mode) do
            {:ok, file_info} = File.stat(safe_path)

            {:ok,
             %{
               path: path,
               size: file_info.size,
               mode: mode,
               backed_up: File.exists?("#{safe_path}.backup"),
               approved: true
             }}
          else
            {:error, reason} -> {:error, "Failed to write file: #{inspect(reason)}"}
          end

        {:ok, :rejected} ->
          {:error, "File write rejected by user via Google Chat"}

        {:error, reason} ->
          {:error, "Approval failed: #{inspect(reason)}"}
      end
    else
      {:error, reason} -> {:error, "Failed to write file: #{inspect(reason)}"}
    end
  end

  def file_list(%{} = args, _ctx) do
    path = Map.get(args, "path", ".")
    recursive = Map.get(args, "recursive", false)
    pattern = Map.get(args, "pattern")

    with {:ok, safe_path} <- validate_path(path),
         {:ok, files} <- list_files(safe_path, recursive, pattern) do
      {:ok,
       %{
         path: path,
         files: files,
         count: length(files)
       }}
    else
      {:error, reason} -> {:error, "Failed to list files: #{inspect(reason)}"}
    end
  end

  def file_search(%{"pattern" => pattern} = args, _ctx) do
    path = Map.get(args, "path", ".")
    limit = Map.get(args, "limit", 50)

    with {:ok, safe_path} <- validate_path(path),
         {:ok, matches} <- search_files(safe_path, pattern, limit) do
      {:ok,
       %{
         pattern: pattern,
         matches: matches,
         count: length(matches)
       }}
    else
      {:error, reason} -> {:error, "Failed to search files: #{inspect(reason)}"}
    end
  end

  def file_stats(%{"path" => path}, _ctx) do
    with {:ok, safe_path} <- validate_path(path),
         {:ok, file_info} <- File.stat(safe_path) do
      {:ok,
       %{
         path: path,
         size: file_info.size,
         type: file_info.type,
         modified: file_info.mtime |> NaiveDateTime.from_erl!() |> to_string(),
         permissions: format_permissions(file_info.mode)
       }}
    else
      {:error, :enoent} -> {:error, "File not found: #{path}"}
      {:error, reason} -> {:error, "Failed to get file stats: #{inspect(reason)}"}
    end
  end

  def file_exists(%{"path" => path}, _ctx) do
    with {:ok, safe_path} <- validate_path(path) do
      exists = File.exists?(safe_path)

      type =
        cond do
          File.dir?(safe_path) -> "directory"
          File.regular?(safe_path) -> "file"
          true -> "unknown"
        end

      {:ok,
       %{
         path: path,
         exists: exists,
         type: if(exists, do: type, else: nil)
       }}
    else
      {:error, reason} -> {:error, "Failed to check file: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp validate_path(path) do
    cond do
      String.starts_with?(path, "/") ->
        {:error, "Absolute paths not allowed"}

      String.contains?(path, "..") ->
        {:error, "Path traversal not allowed"}

      true ->
        {:ok, path}
    end
  end

  defp validate_extension(path) do
    ext = Path.extname(path)

    if ext in @allowed_extensions or ext == "" do
      :ok
    else
      {:error, "File extension '#{ext}' not allowed"}
    end
  end

  defp check_file_size(size) when size > @max_read_size do
    {:error, :file_too_large}
  end

  defp check_file_size(size) when is_integer(size) and size >= 0 do
    :ok
  end

  defp check_file_size(_size) do
    {:error, :invalid_size}
  end

  defp maybe_backup_file(path, "overwrite") do
    if File.exists?(path) do
      backup_path = "#{path}.backup.#{DateTime.utc_now() |> DateTime.to_unix()}"

      case File.cp(path, backup_path) do
        :ok ->
          Logger.info("Created backup: #{backup_path}")
          :ok

        {:error, reason} ->
          Logger.warning("Failed to create backup: #{inspect(reason)}")
          {:error, reason}
      end
    else
      :ok
    end
  end

  defp maybe_backup_file(_path, "append") do
    # For append mode, we don't need to backup since we're not overwriting
    :ok
  end

  defp maybe_backup_file(_path, _mode) do
    :ok
  end

  defp write_file(path, content, "append") do
    File.write(path, content, [:append])
  end

  defp write_file(path, content, "overwrite") do
    File.write(path, content)
  end

  defp generate_diff(old_content, new_content, path) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")

    """
    --- a/#{path}
    +++ b/#{path}
    @@ -1,#{length(old_lines)} +1,#{length(new_lines)} @@
    #{format_diff_lines(old_lines, new_lines)}
    """
  end

  defp format_diff_lines(old_lines, new_lines) do
    # Simple line-by-line diff (could use proper diff algorithm)
    old_formatted = Enum.map(old_lines, &"-#{&1}")
    new_formatted = Enum.map(new_lines, &"+#{&1}")

    (old_formatted ++ new_formatted)
    # Limit to 100 lines for Google Chat
    |> Enum.take(100)
    |> Enum.join("\n")
  end

  defp list_files(path, recursive, pattern) do
    glob_pattern =
      if pattern do
        if recursive do
          Path.join(path, "**/" <> pattern)
        else
          Path.join(path, pattern)
        end
      else
        if recursive do
          Path.join(path, "**/*")
        else
          Path.join(path, "*")
        end
      end

    files =
      Path.wildcard(glob_pattern)
      |> Enum.map(fn file_path ->
        case File.stat(file_path) do
          {:ok, info} ->
            %{
              name: Path.basename(file_path),
              path: file_path,
              type: info.type,
              size: info.size
            }

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, files}
  end

  defp search_files(path, pattern, limit) do
    glob_pattern = Path.join(path, "**/" <> pattern)

    matches =
      Path.wildcard(glob_pattern)
      |> Enum.take(limit)
      |> Enum.map(fn file_path ->
        %{
          name: Path.basename(file_path),
          path: file_path,
          directory: Path.dirname(file_path)
        }
      end)

    {:ok, matches}
  end

  defp format_permissions(mode) do
    # Convert file mode to rwxrwxrwx format
    user = format_permission_set(Bitwise.>>>(mode, 6))
    group = format_permission_set(Bitwise.>>>(mode, 3))
    other = format_permission_set(mode)

    user <> group <> other
  end

  defp format_permission_set(mode) do
    r = if Bitwise.band(mode, 4) != 0, do: "r", else: "-"
    w = if Bitwise.band(mode, 2) != 0, do: "w", else: "-"
    x = if Bitwise.band(mode, 1) != 0, do: "x", else: "-"
    r <> w <> x
  end
end
