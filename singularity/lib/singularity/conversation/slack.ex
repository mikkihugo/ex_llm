defmodule Singularity.Conversation.Slack do
  @moduledoc """
  Slack integration for human-agent conversations.

  Mobile & desktop friendly alternative to Google Chat.
  Supports rich interactive messages with buttons and attachments.

  ## Setup

  1. **Create Slack App:**
     - Go to https://api.slack.com/apps
     - Click "Create New App" → "From scratch"
     - Name: "Singularity Agent"
     - Select your workspace

  2. **Add Incoming Webhooks:**
     - In app settings → "Incoming Webhooks"
     - Activate Incoming Webhooks: ON
     - Click "Add New Webhook to Workspace"
     - Select channel (e.g., #agent-notifications)
     - Copy webhook URL

  3. **Enable Interactive Components (for buttons):**
     - In app settings → "Interactivity & Shortcuts"
     - Turn on Interactivity
     - Set Request URL: https://your-domain.com/slack/interactive
       (This will be your Phoenix endpoint to handle button clicks)
     - Save Changes

  4. **Set Environment Variables:**
     ```bash
     export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
     export SLACK_BOT_TOKEN="xoxb-..."  # Optional, for advanced features
     export WEB_URL="http://localhost:4000"  # Your Phoenix app URL
     ```

  5. **Add to config/config.exs:**
     ```elixir
     config :singularity,
       slack_webhook_url: System.get_env("SLACK_WEBHOOK_URL"),
       slack_bot_token: System.get_env("SLACK_BOT_TOKEN"),
       web_url: System.get_env("WEB_URL") || "http://localhost:4000"
     ```

  ## Usage

      # Simple notification
      Slack.notify("✅ Task completed!")

      # Ask for approval
      Slack.ask_approval(%{
        title: "Deploy to production?",
        description: "New features ready",
        impact: "High",
        estimated_time: "5 minutes",
        confidence: 95,
        id: "approval-123"
      })

      # Ask a question
      Slack.ask_question(%{
        question: "Should I refactor this module?",
        urgency: :high,
        context: %{file: "lib/my_module.ex"},
        id: "question-456"
      })

      # Daily summary
      Slack.daily_summary(%{
        completed_tasks: 10,
        failed_tasks: 1,
        deployments: 3,
        avg_confidence: 92
      })
  """

  require Logger

  @webhook_url Application.compile_env(:singularity, :slack_webhook_url) ||
                 System.get_env("SLACK_WEBHOOK_URL")

  @bot_token Application.compile_env(:singularity, :slack_bot_token) ||
               System.get_env("SLACK_BOT_TOKEN") ||
               System.get_env("SLACK_TOKEN")  # Also check SLACK_TOKEN

  @web_url Application.compile_env(:singularity, :web_url, "http://localhost:4000")

  @default_channel Application.compile_env(:singularity, :slack_default_channel) ||
                     System.get_env("SLACK_DEFAULT_CHANNEL") ||
                     "#agent-notifications"

  ## Public API

  @doc "Send a simple text message"
  def notify(text) when is_binary(text) do
    send_message(%{
      text: text,
      blocks: [
        %{
          type: "section",
          text: %{
            type: "mrkdwn",
            text: text
          }
        }
      ]
    })
  end

  @doc "Ask human for approval on a recommendation"
  def ask_approval(recommendation) do
    send_message(%{
      text: "💡 Agent Recommendation: #{recommendation.title || recommendation.description}",
      blocks: [
        # Header
        %{
          type: "header",
          text: %{
            type: "plain_text",
            text: "💡 Agent Recommendation",
            emoji: true
          }
        },
        # Title & Description
        %{
          type: "section",
          text: %{
            type: "mrkdwn",
            text:
              "*#{recommendation.title || recommendation.description || "New Recommendation"}*\n#{recommendation.description || ""}"
          }
        },
        # Details fields
        %{
          type: "section",
          fields: [
            %{
              type: "mrkdwn",
              text: "*📊 Impact:*\n#{recommendation.impact || "Unknown"}"
            },
            %{
              type: "mrkdwn",
              text: "*⏱️ Time:*\n#{recommendation.estimated_time || "Unknown"}"
            },
            %{
              type: "mrkdwn",
              text: "*🎯 Confidence:*\n#{recommendation.confidence || 95}%"
            }
          ]
        },
        # Divider
        %{type: "divider"},
        # Action buttons
        %{
          type: "actions",
          elements: [
            %{
              type: "button",
              text: %{
                type: "plain_text",
                text: "✅ Approve",
                emoji: true
              },
              style: "primary",
              value: "approve_#{recommendation.id}",
              action_id: "approve_recommendation",
              url: "#{@web_url}/approve/#{recommendation.id}"
            },
            %{
              type: "button",
              text: %{
                type: "plain_text",
                text: "❌ Reject",
                emoji: true
              },
              style: "danger",
              value: "reject_#{recommendation.id}",
              action_id: "reject_recommendation",
              url: "#{@web_url}/reject/#{recommendation.id}"
            }
          ]
        }
      ]
    })
  end

  @doc "Ask human a question"
  def ask_question(question) do
    context_text =
      if question.context && map_size(question.context) > 0 do
        "\n\n*Context:* #{format_context(question.context)}"
      else
        ""
      end

    send_message(%{
      text: "🤔 Agent Question: #{question.question}",
      blocks: [
        # Header
        %{
          type: "header",
          text: %{
            type: "plain_text",
            text: "🤔 Agent Question",
            emoji: true
          }
        },
        # Question
        %{
          type: "section",
          text: %{
            type: "mrkdwn",
            text:
              "*#{question.question}*\n#{urgency_text(question.urgency)}#{context_text}"
          }
        },
        # Divider
        %{type: "divider"},
        # Answer button
        %{
          type: "actions",
          elements: [
            %{
              type: "button",
              text: %{
                type: "plain_text",
                text: "💬 Answer",
                emoji: true
              },
              style: "primary",
              value: "answer_#{question.id}",
              action_id: "answer_question",
              url: "#{@web_url}/answer/#{question.id}"
            }
          ]
        }
      ]
    })
  end

  @doc "Send daily status update"
  def daily_summary(summary) do
    pending_questions =
      case summary.pending_questions || [] do
        [] ->
          []

        questions ->
          [
            %{
              type: "section",
              text: %{
                type: "mrkdwn",
                text:
                  "*🤔 Waiting on your input:*\n" <>
                    Enum.map_join(questions, "\n", &"• #{&1.question}")
              }
            }
          ]
      end

    top_recommendation =
      if summary.top_recommendation do
        [
          %{
            type: "section",
            text: %{
              type: "mrkdwn",
              text: "*💡 Top recommendation:*\n#{summary.top_recommendation}"
            }
          }
        ]
      else
        []
      end

    send_message(%{
      text: "☀️ Daily Agent Report - #{Date.utc_today()}",
      blocks:
        [
          # Header
          %{
            type: "header",
            text: %{
              type: "plain_text",
              text: "☀️ Daily Agent Report",
              emoji: true
            }
          },
          # Date
          %{
            type: "context",
            elements: [
              %{
                type: "mrkdwn",
                text: "📅 *#{Date.utc_today()}*"
              }
            ]
          },
          # Stats
          %{
            type: "section",
            fields: [
              %{
                type: "mrkdwn",
                text: "*✅ Completed:*\n#{summary.completed_tasks} tasks"
              },
              %{
                type: "mrkdwn",
                text: "*⚠️ Failed:*\n#{summary.failed_tasks} tasks"
              },
              %{
                type: "mrkdwn",
                text: "*🚀 Deployed:*\n#{summary.deployments} changes"
              },
              %{
                type: "mrkdwn",
                text: "*📈 Avg Confidence:*\n#{summary.avg_confidence}%"
              }
            ]
          }
        ] ++
          pending_questions ++
          top_recommendation ++
          [
            # Divider
            %{type: "divider"},
            # Dashboard button
            %{
              type: "actions",
              elements: [
                %{
                  type: "button",
                  text: %{
                    type: "plain_text",
                    text: "📊 View Dashboard",
                    emoji: true
                  },
                  url: "#{@web_url}/dashboard"
                }
              ]
            }
          ]
    })
  end

  @doc "Notify about deployment"
  def deployment_notification(deployment) do
    {status_emoji, status_text, style} =
      case deployment.status do
        :success -> {"✅", "Success", "primary"}
        :failed -> {"❌", "Failed", "danger"}
        :in_progress -> {"⏳", "In Progress", nil}
        _ -> {"📦", "Deployment", nil}
      end

    failure_section =
      if deployment.status == :failed && deployment.failure_reason do
        [
          %{
            type: "section",
            text: %{
              type: "mrkdwn",
              text: "*⚠️ Reason:*\n#{deployment.failure_reason}"
            }
          }
        ]
      else
        []
      end

    send_message(%{
      text: "#{status_emoji} Deployment #{status_text}",
      blocks:
        [
          # Header
          %{
            type: "header",
            text: %{
              type: "plain_text",
              text: "#{status_emoji} Deployment #{status_text}",
              emoji: true
            }
          },
          # Description
          %{
            type: "section",
            text: %{
              type: "mrkdwn",
              text: "*#{deployment.description || "Deployment"}*"
            }
          },
          # Details
          %{
            type: "section",
            fields: [
              %{
                type: "mrkdwn",
                text: "*📦 Version:*\n#{deployment.version}"
              },
              %{
                type: "mrkdwn",
                text: "*⏱️ Time:*\n#{relative_time(deployment.timestamp)}"
              },
              %{
                type: "mrkdwn",
                text: "*🎯 Confidence:*\n#{deployment.confidence || 0}%"
              }
            ]
          }
        ] ++ failure_section
    })
  end

  @doc "Notify about policy changes"
  def policy_change(change) do
    send_message(%{
      text: "⚙️ Policy Updated",
      blocks: [
        # Header
        %{
          type: "header",
          text: %{
            type: "plain_text",
            text: "⚙️ Policy Updated",
            emoji: true
          }
        },
        # Change description
        %{
          type: "section",
          text: %{
            type: "mrkdwn",
            text:
              "*I adjusted deployment settings*\n\n" <>
                "*Parameter:* #{change.parameter}\n" <>
                "*Change:* `#{change.old_value}` → `#{change.new_value}`\n\n" <>
                "*Reason:* #{change.reason}"
          }
        },
        # Stats
        %{
          type: "section",
          fields: [
            %{
              type: "mrkdwn",
              text: "*📈 Recent success rate:*\n#{change.success_rate}%"
            },
            %{
              type: "mrkdwn",
              text: "*📊 Sample size:*\n#{change.sample_size} tasks"
            }
          ]
        }
      ]
    })
  end

  ## Internal Functions

  defp send_message(payload) do
    # Try bot token API first (more powerful), fallback to webhook
    cond do
      not is_nil(@bot_token) ->
        send_via_bot_token(payload)

      not is_nil(@webhook_url) ->
        send_via_webhook(payload)

      true ->
        Logger.warning("Slack not configured. Set SLACK_TOKEN or SLACK_WEBHOOK_URL")
        {:error, :not_configured}
    end
  end

  defp send_via_bot_token(payload) do
    # Use Slack Web API with bot token (more features)
    url = "https://slack.com/api/chat.postMessage"

    body =
      payload
      |> Map.put(:channel, @default_channel)
      |> Jason.encode!()

    headers = [
      {"Authorization", "Bearer #{@bot_token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(url, body: body, headers: headers) do
      {:ok, %{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"ok" => true}} ->
            Logger.debug("Sent Slack message via bot token")
            :ok

          {:ok, %{"ok" => false, "error" => error}} ->
            Logger.error("Slack API error: #{error}")
            {:error, {:slack_api_error, error}}

          {:error, _} ->
            Logger.error("Failed to parse Slack response")
            {:error, :parse_error}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Slack API HTTP error: #{status} - #{inspect(body)}")
        {:error, {:http_error, status}}

      {:error, error} ->
        Logger.error("Failed to send Slack message: #{inspect(error)}")
        {:error, error}
    end
  end

  defp send_via_webhook(payload) do
    case Req.post(@webhook_url, json: payload) do
      {:ok, %{status: 200}} ->
        Logger.debug("Sent Slack notification via webhook")
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Slack webhook error: #{status} - #{inspect(body)}")
        {:error, {:slack_webhook_error, status, body}}

      {:error, error} ->
        Logger.error("Failed to send Slack webhook: #{inspect(error)}")
        {:error, error}
    end
  end

  defp urgency_text(:critical), do: "🚨 *URGENT* - Please respond ASAP"
  defp urgency_text(:high), do: "⚠️ *High priority*"
  defp urgency_text(:normal), do: "📋 Normal priority"
  defp urgency_text(:low), do: "💤 Low priority"
  defp urgency_text(_), do: "📋 Normal priority"

  defp relative_time(datetime) when is_struct(datetime, DateTime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      seconds_ago < 60 -> "just now"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)} minutes ago"
      seconds_ago < 86400 -> "#{div(seconds_ago, 3600)} hours ago"
      true -> "#{div(seconds_ago, 86400)} days ago"
    end
  end

  defp relative_time(_), do: "recently"

  defp format_context(context) when is_map(context) do
    context
    |> Enum.map(fn {k, v} -> "`#{k}`: #{inspect(v)}" end)
    |> Enum.join(", ")
  end

  defp format_context(_), do: ""
end
