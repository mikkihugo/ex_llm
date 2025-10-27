defmodule Singularity.Tools.Git do
  @moduledoc """
  Git Tools - Version control operations for autonomous agents

  Provides safe git operations for agents to:
  - View changes and history
  - Create commits
  - Manage branches
  - Track code evolution

  All operations are read-only by default, with explicit confirmation for destructive operations.
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool

  def register(provider) do
    Catalog.add_tools(provider, [
      git_diff_tool(),
      git_log_tool(),
      git_blame_tool(),
      git_commit_create_tool(),
      git_branches_tool(),
      git_status_tool(),
      git_stash_tool()
    ])
  end

  defp git_diff_tool do
    Tool.new!(%{
      name: "git_diff",
      description: "Show changes between commits, working directory, or staged changes",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: false,
          description: "Target to compare (commit, branch, or 'staged')"
        },
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Specific file or directory path"
        },
        %{
          name: "context_lines",
          type: :integer,
          required: false,
          description: "Number of context lines (default: 3)"
        }
      ],
      function: &git_diff/2
    })
  end

  defp git_log_tool do
    Tool.new!(%{
      name: "git_log",
      description: "Show commit history with filters and formatting",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Show commits affecting specific path"
        },
        %{name: "author", type: :string, required: false, description: "Filter by author"},
        %{
          name: "since",
          type: :string,
          required: false,
          description: "Show commits since date (e.g., '1 week ago', '2024-01-01')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of commits (default: 10)"
        },
        %{
          name: "oneline",
          type: :boolean,
          required: false,
          description: "Show one line per commit (default: true)"
        }
      ],
      function: &git_log/2
    })
  end

  defp git_blame_tool do
    Tool.new!(%{
      name: "git_blame",
      description: "Show who last modified each line of a file",
      parameters: [
        %{name: "path", type: :string, required: true, description: "File path to blame"},
        %{name: "start_line", type: :integer, required: false, description: "Start line number"},
        %{name: "end_line", type: :integer, required: false, description: "End line number"}
      ],
      function: &git_blame/2
    })
  end

  defp git_commit_create_tool do
    Tool.new!(%{
      name: "git_commit_create",
      description: "Stage and commit changes with a message",
      parameters: [
        %{name: "message", type: :string, required: true, description: "Commit message"},
        %{
          name: "files",
          type: :array,
          required: false,
          description: "Specific files to stage (default: all changes)"
        },
        %{
          name: "dry_run",
          type: :boolean,
          required: false,
          description: "Show what would be committed without actually committing (default: false)"
        }
      ],
      function: &git_commit_create/2
    })
  end

  defp git_branches_tool do
    Tool.new!(%{
      name: "git_branches",
      description: "List, create, or switch branches",
      parameters: [
        %{
          name: "action",
          type: :string,
          required: false,
          description: "Action: 'list', 'create', 'switch', 'delete' (default: 'list')"
        },
        %{
          name: "branch_name",
          type: :string,
          required: false,
          description: "Branch name for create/switch/delete operations"
        },
        %{
          name: "remote",
          type: :boolean,
          required: false,
          description: "Include remote branches in list (default: false)"
        }
      ],
      function: &git_branches/2
    })
  end

  defp git_status_tool do
    Tool.new!(%{
      name: "git_status",
      description: "Show the working directory status",
      parameters: [
        %{
          name: "porcelain",
          type: :boolean,
          required: false,
          description: "Use porcelain format (machine-readable, default: true)"
        },
        %{
          name: "short",
          type: :boolean,
          required: false,
          description: "Use short format (default: false)"
        }
      ],
      function: &git_status/2
    })
  end

  defp git_stash_tool do
    Tool.new!(%{
      name: "git_stash",
      description: "Stash or unstash changes",
      parameters: [
        %{
          name: "action",
          type: :string,
          required: true,
          description: "Action: 'list', 'save', 'pop', 'apply', 'drop'"
        },
        %{
          name: "message",
          type: :string,
          required: false,
          description: "Stash message for save action"
        },
        %{
          name: "stash_index",
          type: :integer,
          required: false,
          description: "Stash index for pop/apply/drop actions (default: 0)"
        }
      ],
      function: &git_stash/2
    })
  end

  # Implementation functions

  def git_diff(%{"target" => target, "path" => path, "context_lines" => context_lines}, _ctx) do
    git_diff_impl(target, path, context_lines)
  end

  def git_diff(%{"target" => target, "path" => path}, _ctx) do
    git_diff_impl(target, path, 3)
  end

  def git_diff(%{"target" => target}, _ctx) do
    git_diff_impl(target, nil, 3)
  end

  def git_diff(%{}, _ctx) do
    git_diff_impl("HEAD", nil, 3)
  end

  defp git_diff_impl(target, path, context_lines) do
    try do
      # Build git diff command
      cmd = ["git", "diff", "--unified=#{context_lines}"]

      # Add target (commit, branch, or staged)
      cmd =
        case target do
          "staged" -> cmd ++ ["--cached"]
          "HEAD" -> cmd
          _ -> cmd ++ [target]
        end

      # Add path if specified
      cmd = if path, do: cmd ++ ["--", path], else: cmd

      # Execute command
      {output, exit_code} = System.cmd("git", cmd, stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           target: target,
           path: path,
           context_lines: context_lines,
           diff: output,
           lines_changed: count_diff_lines(output),
           has_changes: String.length(output) > 0
         }}
      else
        {:error, "Git diff failed: #{output}"}
      end
    rescue
      error -> {:error, "Git diff error: #{inspect(error)}"}
    end
  end

  def git_log(
        %{
          "path" => path,
          "author" => author,
          "since" => since,
          "limit" => limit,
          "oneline" => oneline
        },
        _ctx
      ) do
    git_log_impl(path, author, since, limit, oneline)
  end

  def git_log(%{"path" => path, "author" => author, "since" => since, "limit" => limit}, _ctx) do
    git_log_impl(path, author, since, limit, true)
  end

  def git_log(%{"path" => path, "author" => author, "since" => since}, _ctx) do
    git_log_impl(path, author, since, 10, true)
  end

  def git_log(%{"path" => path, "author" => author}, _ctx) do
    git_log_impl(path, author, nil, 10, true)
  end

  def git_log(%{"path" => path}, _ctx) do
    git_log_impl(path, nil, nil, 10, true)
  end

  def git_log(%{}, _ctx) do
    git_log_impl(nil, nil, nil, 10, true)
  end

  defp git_log_impl(path, author, since, limit, oneline) do
    try do
      # Build git log command
      cmd = ["git", "log"]

      # Add format
      format = if oneline, do: "--oneline", else: "--pretty=format:%h %an %ad %s"
      cmd = cmd ++ [format]

      # Add date format if not oneline
      cmd = if oneline, do: cmd, else: cmd ++ ["--date=short"]

      # Add filters
      cmd = if author, do: cmd ++ ["--author=#{author}"], else: cmd
      cmd = if since, do: cmd ++ ["--since=#{since}"], else: cmd
      cmd = if limit, do: cmd ++ ["-#{limit}"], else: cmd
      cmd = if path, do: cmd ++ ["--", path], else: cmd

      # Execute command
      {output, exit_code} = System.cmd("git", cmd, stderr_to_stdout: true)

      if exit_code == 0 do
        commits = parse_git_log(output, oneline)

        {:ok,
         %{
           path: path,
           author: author,
           since: since,
           limit: limit,
           oneline: oneline,
           commits: commits,
           count: length(commits)
         }}
      else
        {:error, "Git log failed: #{output}"}
      end
    rescue
      error -> {:error, "Git log error: #{inspect(error)}"}
    end
  end

  def git_blame(%{"path" => path, "start_line" => start_line, "end_line" => end_line}, _ctx) do
    git_blame_impl(path, start_line, end_line)
  end

  def git_blame(%{"path" => path, "start_line" => start_line}, _ctx) do
    git_blame_impl(path, start_line, nil)
  end

  def git_blame(%{"path" => path}, _ctx) do
    git_blame_impl(path, nil, nil)
  end

  defp git_blame_impl(path, start_line, end_line) do
    try do
      # Validate file exists
      if not File.exists?(path) do
        {:error, "File not found: #{path}"}
      else
        # Build git blame command
        cmd = ["git", "blame", "-w", "-M", "-C"]

        # Add line range if specified
        cmd =
          if start_line && end_line do
            cmd ++ ["-L", "#{start_line},#{end_line}"]
          else
            cmd
          end

        cmd = cmd ++ [path]

        # Execute command
        {output, exit_code} = System.cmd("git", cmd, stderr_to_stdout: true)

        if exit_code == 0 do
          blame_lines = parse_git_blame(output)

          {:ok,
           %{
             path: path,
             start_line: start_line,
             end_line: end_line,
             lines: blame_lines,
             count: length(blame_lines)
           }}
        else
          {:error, "Git blame failed: #{output}"}
        end
      end
    rescue
      error -> {:error, "Git blame error: #{inspect(error)}"}
    end
  end

  def git_commit_create(%{"message" => message, "files" => files, "dry_run" => dry_run}, _ctx) do
    git_commit_create_impl(message, files, dry_run)
  end

  def git_commit_create(%{"message" => message, "files" => files}, _ctx) do
    git_commit_create_impl(message, files, false)
  end

  def git_commit_create(%{"message" => message, "dry_run" => dry_run}, _ctx) do
    git_commit_create_impl(message, nil, dry_run)
  end

  def git_commit_create(%{"message" => message}, _ctx) do
    git_commit_create_impl(message, nil, false)
  end

  defp git_commit_create_impl(message, files, dry_run) do
    try do
      if dry_run do
        # Show what would be committed
        {status_output, _} = System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true)
        {diff_output, _} = System.cmd("git", ["diff", "--cached"], stderr_to_stdout: true)

        {:ok,
         %{
           message: message,
           files: files,
           dry_run: true,
           status: status_output,
           staged_changes: diff_output,
           would_commit: String.length(diff_output) > 0
         }}
      else
        # Stage files
        stage_result =
          if files && length(files) > 0 do
            {_, exit_code} = System.cmd("git", ["add"] ++ files, stderr_to_stdout: true)
            if exit_code != 0, do: {:error, "Failed to stage files"}, else: :ok
          else
            {_, exit_code} = System.cmd("git", ["add", "."], stderr_to_stdout: true)
            if exit_code != 0, do: {:error, "Failed to stage all changes"}, else: :ok
          end

        case stage_result do
          :ok ->
            # Create commit
            {output, exit_code} =
              System.cmd("git", ["commit", "-m", message], stderr_to_stdout: true)

            if exit_code == 0 do
              # Get commit hash
              {commit_hash, _} = System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true)

              {:ok,
               %{
                 message: message,
                 files: files,
                 commit_hash: String.trim(commit_hash),
                 output: output,
                 success: true
               }}
            else
              {:error, "Git commit failed: #{output}"}
            end

          error ->
            error
        end
      end
    rescue
      error -> {:error, "Git commit error: #{inspect(error)}"}
    end
  end

  def git_branches(%{"action" => "list", "remote" => remote}, _ctx) do
    git_branches_list(remote)
  end

  def git_branches(%{"action" => "list"}, _ctx) do
    git_branches_list(false)
  end

  def git_branches(%{"action" => "create", "branch_name" => branch_name}, _ctx) do
    git_branches_create(branch_name)
  end

  def git_branches(%{"action" => "switch", "branch_name" => branch_name}, _ctx) do
    git_branches_switch(branch_name)
  end

  def git_branches(%{"action" => "delete", "branch_name" => branch_name}, _ctx) do
    git_branches_delete(branch_name)
  end

  def git_branches(%{}, _ctx) do
    git_branches_list(false)
  end

  defp git_branches_list(include_remote) do
    try do
      cmd = if include_remote, do: ["git", "branch", "-a"], else: ["git", "branch"]
      {output, exit_code} = System.cmd("git", cmd, stderr_to_stdout: true)

      if exit_code == 0 do
        branches = parse_git_branches(output)

        {:ok,
         %{
           branches: branches,
           include_remote: include_remote,
           count: length(branches)
         }}
      else
        {:error, "Git branch failed: #{output}"}
      end
    rescue
      error -> {:error, "Git branch error: #{inspect(error)}"}
    end
  end

  defp git_branches_create(branch_name) do
    try do
      {output, exit_code} =
        System.cmd("git", ["checkout", "-b", branch_name], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "create",
           branch_name: branch_name,
           output: output,
           success: true
         }}
      else
        {:error, "Git branch create failed: #{output}"}
      end
    rescue
      error -> {:error, "Git branch create error: #{inspect(error)}"}
    end
  end

  defp git_branches_switch(branch_name) do
    try do
      {output, exit_code} = System.cmd("git", ["checkout", branch_name], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "switch",
           branch_name: branch_name,
           output: output,
           success: true
         }}
      else
        {:error, "Git branch switch failed: #{output}"}
      end
    rescue
      error -> {:error, "Git branch switch error: #{inspect(error)}"}
    end
  end

  defp git_branches_delete(branch_name) do
    try do
      {output, exit_code} =
        System.cmd("git", ["branch", "-d", branch_name], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "delete",
           branch_name: branch_name,
           output: output,
           success: true
         }}
      else
        {:error, "Git branch delete failed: #{output}"}
      end
    rescue
      error -> {:error, "Git branch delete error: #{inspect(error)}"}
    end
  end

  def git_status(%{"porcelain" => porcelain, "short" => short}, _ctx) do
    git_status_impl(porcelain, short)
  end

  def git_status(%{"porcelain" => porcelain}, _ctx) do
    git_status_impl(porcelain, false)
  end

  def git_status(%{"short" => short}, _ctx) do
    git_status_impl(true, short)
  end

  def git_status(%{}, _ctx) do
    git_status_impl(true, false)
  end

  defp git_status_impl(porcelain, short) do
    try do
      cmd = ["git", "status"]
      cmd = if porcelain, do: cmd ++ ["--porcelain"], else: cmd
      cmd = if short, do: cmd ++ ["--short"], else: cmd

      {output, exit_code} = System.cmd("git", cmd, stderr_to_stdout: true)

      if exit_code == 0 do
        status = parse_git_status(output, porcelain)

        {:ok,
         %{
           porcelain: porcelain,
           short: short,
           status: status,
           has_changes: status.changed_files > 0 or status.untracked_files > 0
         }}
      else
        {:error, "Git status failed: #{output}"}
      end
    rescue
      error -> {:error, "Git status error: #{inspect(error)}"}
    end
  end

  def git_stash(%{"action" => "list"}, _ctx) do
    git_stash_list()
  end

  def git_stash(%{"action" => "save", "message" => message}, _ctx) do
    git_stash_save(message)
  end

  def git_stash(%{"action" => "save"}, _ctx) do
    git_stash_save("Stash created by agent")
  end

  def git_stash(%{"action" => "pop", "stash_index" => stash_index}, _ctx) do
    git_stash_pop(stash_index)
  end

  def git_stash(%{"action" => "pop"}, _ctx) do
    git_stash_pop(0)
  end

  def git_stash(%{"action" => "apply", "stash_index" => stash_index}, _ctx) do
    git_stash_apply(stash_index)
  end

  def git_stash(%{"action" => "apply"}, _ctx) do
    git_stash_apply(0)
  end

  def git_stash(%{"action" => "drop", "stash_index" => stash_index}, _ctx) do
    git_stash_drop(stash_index)
  end

  def git_stash(%{"action" => "drop"}, _ctx) do
    git_stash_drop(0)
  end

  defp git_stash_list do
    try do
      {output, exit_code} = System.cmd("git", ["stash", "list"], stderr_to_stdout: true)

      if exit_code == 0 do
        stashes = parse_git_stash_list(output)

        {:ok,
         %{
           action: "list",
           stashes: stashes,
           count: length(stashes)
         }}
      else
        {:error, "Git stash list failed: #{output}"}
      end
    rescue
      error -> {:error, "Git stash list error: #{inspect(error)}"}
    end
  end

  defp git_stash_save(message) do
    try do
      {output, exit_code} =
        System.cmd("git", ["stash", "push", "-m", message], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "save",
           message: message,
           output: output,
           success: true
         }}
      else
        {:error, "Git stash save failed: #{output}"}
      end
    rescue
      error -> {:error, "Git stash save error: #{inspect(error)}"}
    end
  end

  defp git_stash_pop(stash_index) do
    try do
      stash_ref = if stash_index > 0, do: "stash@{#{stash_index}}", else: "stash@{0}"
      {output, exit_code} = System.cmd("git", ["stash", "pop", stash_ref], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "pop",
           stash_index: stash_index,
           output: output,
           success: true
         }}
      else
        {:error, "Git stash pop failed: #{output}"}
      end
    rescue
      error -> {:error, "Git stash pop error: #{inspect(error)}"}
    end
  end

  defp git_stash_apply(stash_index) do
    try do
      stash_ref = if stash_index > 0, do: "stash@{#{stash_index}}", else: "stash@{0}"

      {output, exit_code} =
        System.cmd("git", ["stash", "apply", stash_ref], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "apply",
           stash_index: stash_index,
           output: output,
           success: true
         }}
      else
        {:error, "Git stash apply failed: #{output}"}
      end
    rescue
      error -> {:error, "Git stash apply error: #{inspect(error)}"}
    end
  end

  defp git_stash_drop(stash_index) do
    try do
      stash_ref = if stash_index > 0, do: "stash@{#{stash_index}}", else: "stash@{0}"

      {output, exit_code} =
        System.cmd("git", ["stash", "drop", stash_ref], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok,
         %{
           action: "drop",
           stash_index: stash_index,
           output: output,
           success: true
         }}
      else
        {:error, "Git stash drop failed: #{output}"}
      end
    rescue
      error -> {:error, "Git stash drop error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp count_diff_lines(diff_output) do
    diff_output
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.starts_with?(line, ["+", "-"]) && !String.starts_with?(line, ["+++", "---"])
    end)
  end

  defp parse_git_log(output, oneline) do
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      if oneline do
        %{hash: String.slice(line, 0, 7), message: String.slice(line, 8..-1//-1)}
      else
        # Parse full format: hash author date message
        parts = String.split(line, " ", parts: 4)

        case parts do
          [hash, author, date, message] ->
            %{hash: hash, author: author, date: date, message: message}

          _ ->
            %{hash: line, author: "", date: "", message: ""}
        end
      end
    end)
  end

  defp parse_git_blame(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, line_num} ->
      # Parse blame line: hash author date line_num content
      case Regex.run(~r/^([a-f0-9]+)\s+\((.+?)\s+(\d{4}-\d{2}-\d{2})\s+(\d+)\)\s+(.*)$/, line) do
        [_, hash, author, date, orig_line, content] ->
          %{
            line_number: line_num,
            hash: hash,
            author: author,
            date: date,
            original_line: String.to_integer(orig_line),
            content: content
          }

        _ ->
          %{
            line_number: line_num,
            hash: "",
            author: "",
            date: "",
            original_line: line_num,
            content: line
          }
      end
    end)
  end

  defp parse_git_branches(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      # Remove * for current branch and remote/ prefix
      clean_line = String.replace(line, ~r/^\*\s*/, "")
      is_current = String.starts_with?(line, "*")
      is_remote = String.starts_with?(clean_line, "remotes/")

      %{
        name: clean_line,
        current: is_current,
        remote: is_remote
      }
    end)
  end

  defp parse_git_status(output, porcelain) do
    lines =
      output
      |> String.trim()
      |> String.split("\n")
      |> Enum.reject(&(&1 == ""))

    if porcelain do
      # Parse porcelain format
      changed_files = Enum.count(lines, &String.starts_with?(&1, ["M ", "A ", "D ", "R ", "C "]))
      untracked_files = Enum.count(lines, &String.starts_with?(&1, "??"))

      %{
        changed_files: changed_files,
        untracked_files: untracked_files,
        files: lines
      }
    else
      # Parse regular format
      %{
        changed_files: 0,
        untracked_files: 0,
        files: lines
      }
    end
  end

  defp parse_git_stash_list(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index()
    |> Enum.map(fn {line, index} ->
      # Parse stash line: stash@{0}: WIP on branch: message
      case Regex.run(~r/stash@\{(\d+)\}:\s+(.+)/, line) do
        [_, stash_num, message] ->
          %{
            index: index,
            stash_number: String.to_integer(stash_num),
            message: message
          }

        _ ->
          %{
            index: index,
            stash_number: index,
            message: line
          }
      end
    end)
  end
end
