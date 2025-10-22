defmodule Singularity.HITL.GoogleChat do
  @moduledoc """
  Google Chat integration for Human-in-the-Loop (HITL) approval workflow.

  Posts code change requests to Google Chat with interactive buttons.
  Users click ✅ Approve or ❌ Reject to control agent actions.

  ## Setup

  1. Create Google Chat webhook:
     - Go to Google Chat space
     - Click space name → Apps & integrations → Add webhooks
     - Copy webhook URL

  2. Set environment variable:
     export GOOGLE_CHAT_WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/..."

  3. (Optional) Set up interactive cards with Google Chat API:
     - Enable Google Chat API in Google Cloud Console
     - Create service account with Chat Bot permissions
     - Set GOOGLE_CHAT_BOT_TOKEN

  ## Usage

      {:ok, approval} = GoogleChat.post_approval_request(
        file_path: "lib/my_module.ex",
        diff: diff_text,
        description: "Add new feature"
      )

      # Agent waits...
      status = GoogleChat.wait_for_approval(approval.id)  # Blocks until clicked
  """

  require Logger

  @webhook_url System.get_env("GOOGLE_CHAT_WEBHOOK_URL")
  # Truncate large diffs for readability
  @max_diff_lines 50

  @doc """
  Post a code change approval request to Google Chat.

  Returns {:ok, message_id} on success.
  """
  def post_approval_request(file_path, diff, opts \\ []) do
    description = Keyword.get(opts, :description, "Code change request")
    agent_id = Keyword.get(opts, :agent_id, "unknown")

    # Truncate diff if too long
    truncated_diff = truncate_diff(diff, @max_diff_lines)

    card = build_approval_card(file_path, truncated_diff, description, agent_id)

    case post_to_chat(card) do
      {:ok, response} ->
        {:ok, extract_message_id(response)}

      {:error, reason} ->
        Logger.error("Failed to post to Google Chat: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update approval message after user clicks button.

  Changes button state and adds approval/rejection badge.
  """
  def update_message_status(message_id, status, approved_by) do
    badge =
      case status do
        "approved" -> "✅ Approved by #{approved_by}"
        "rejected" -> "❌ Rejected by #{approved_by}"
        _ -> "⏳ Pending"
      end

    # Log the message status update for tracking
    Logger.info("Message status updated",
      message_id: message_id,
      status: status,
      approved_by: approved_by,
      timestamp: DateTime.utc_now()
    )

    # Store the update in database for audit trail
    case store_message_status_update(message_id, status, approved_by) do
      {:ok, _} ->
        Logger.debug("Message status stored in database", message_id: message_id)

      {:error, reason} ->
        Logger.warning("Failed to store message status",
          message_id: message_id,
          reason: reason
        )
    end

    # Note: Updating messages requires Google Chat API (not webhook)
    # For webhook-only mode, we post a new message
    post_to_chat(%{
      text: badge,
      # Use message_id as thread key for context
      thread_key: message_id
    })
  end

  defp store_message_status_update(message_id, status, approved_by) do
    # Store message status updates for audit trail
    # This would typically use Ecto to store in a messages table
    try do
      # Mock database storage - in real implementation, use Ecto
      audit_entry = %{
        message_id: message_id,
        status: status,
        approved_by: approved_by,
        updated_at: DateTime.utc_now(),
        action: "status_update"
      }

      # Store in ETS table for now (in production, use PostgreSQL)
      :ets.insert(:message_audit, {message_id, audit_entry})

      Logger.debug("Message audit entry created",
        message_id: message_id,
        status: status
      )

      {:ok, audit_entry}
    rescue
      error ->
        Logger.error("Failed to create audit entry",
          message_id: message_id,
          error: inspect(error)
        )

        {:error, :storage_failed}
    end
  end

  ## Private Functions

  defp build_approval_card(file_path, diff, description, agent_id) do
    %{
      cards: [
        %{
          header: %{
            title: "🤖 Code Change Request",
            subtitle: "Agent: #{agent_id}",
            imageUrl: "https://fonts.gstatic.com/s/i/productlogos/googleg/v6/24px.svg"
          },
          sections: [
            %{
              widgets: [
                %{
                  textParagraph: %{
                    text: "<b>Description:</b> #{description}"
                  }
                },
                %{
                  textParagraph: %{
                    text: "<b>File:</b> <font color=\"#1a73e8\">#{file_path}</font>"
                  }
                },
                %{
                  textParagraph: %{
                    text: "<b>Diff:</b>\n<pre>#{escape_html(diff)}</pre>"
                  }
                }
              ]
            },
            %{
              widgets: [
                %{
                  buttons: [
                    %{
                      textButton: %{
                        text: "✅ APPROVE",
                        onClick: %{
                          action: %{
                            actionMethodName: "approve",
                            parameters: [
                              %{key: "file_path", value: file_path}
                            ]
                          }
                        }
                      }
                    },
                    %{
                      textButton: %{
                        text: "❌ REJECT",
                        onClick: %{
                          action: %{
                            actionMethodName: "reject",
                            parameters: [
                              %{key: "file_path", value: file_path}
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  end

  defp post_to_chat(payload) do
    if is_nil(@webhook_url) do
      Logger.warning("GOOGLE_CHAT_WEBHOOK_URL not set, skipping Google Chat notification")
      {:error, :webhook_not_configured}
    else
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(payload)

      # Use Finch (better than HTTPoison) for HTTP requests
      request = Finch.build(:post, @webhook_url, headers, body)

      case Finch.request(request, Singularity.HttpClient, receive_timeout: 10_000) do
        {:ok, %{status: 200, body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, decoded} ->
              {:ok, decoded}

            {:error, reason} ->
              Logger.warning("Failed to decode Google Chat response", reason: reason)
              {:ok, %{raw_response: response_body}}
          end

        {:ok, %{status: status, body: error_body}} ->
          Logger.warning("Google Chat webhook failed",
            status: status,
            error: error_body
          )

          {:error, {:http_error, status, error_body}}

        {:error, reason} ->
          Logger.error("Google Chat webhook request failed", reason: reason)
          {:error, reason}
      end
    end
  end

  defp truncate_diff(diff, max_lines) do
    lines = String.split(diff, "\n")

    if length(lines) > max_lines do
      truncated = Enum.take(lines, max_lines)
      Enum.join(truncated, "\n") <> "\n... (truncated, #{length(lines) - max_lines} more lines)"
    else
      diff
    end
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp extract_message_id(response) do
    # Google Chat response includes message name like:
    # "spaces/AAAA/messages/BBBB.CCCC"
    get_in(response, ["name"]) || "unknown"
  end
end
