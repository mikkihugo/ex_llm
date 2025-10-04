defmodule Singularity.Conversation.GoogleChat do
  @moduledoc """
  Google Chat integration - mobile & desktop friendly.
  No code analysis, just business decisions.
  """

  require Logger

  @webhook_url Application.compile_env(:singularity, :google_chat_webhook_url) ||
                 System.get_env("GOOGLE_CHAT_WEBHOOK_URL")

  @web_url Application.compile_env(:singularity, :web_url, "http://localhost:4000")

  ## Public API

  @doc "Send a simple text message"
  def notify(text) when is_binary(text) do
    send_card(%{text: text})
  end

  @doc "Ask human for approval on a recommendation"
  def ask_approval(recommendation) do
    send_card(%{
      header: "💡 Agent Recommendation",
      title: recommendation.title || recommendation.description || "New Recommendation",
      subtitle: recommendation.description,
      sections: [
        field_section([
          {"📊 Impact", recommendation.impact || "Unknown"},
          {"⏱️ Time", recommendation.estimated_time || "Unknown"},
          {"🎯 Confidence", "#{recommendation.confidence || 95}%"}
        ]),
        button_section([
          {"✅ Approve", "#{@web_url}/approve/#{recommendation.id}", :primary},
          {"❌ Reject", "#{@web_url}/reject/#{recommendation.id}", :danger}
        ])
      ]
    })
  end

  @doc "Ask human a question"
  def ask_question(question) do
    send_card(%{
      header: "🤔 Agent Question",
      title: question.question,
      subtitle: urgency_text(question.urgency),
      sections:
        [
          if question.context && map_size(question.context) > 0 do
            text_section("Context: #{format_context(question.context)}")
          end,
          button_section([
            {"💬 Answer", "#{@web_url}/answer/#{question.id}", :primary}
          ])
        ]
        |> Enum.reject(&is_nil/1)
    })
  end

  @doc "Send daily status update"
  def daily_summary(summary) do
    send_card(%{
      header: "☀️ Daily Agent Report",
      title: "#{Date.utc_today()}",
      sections:
        [
          text_section("""
          ✅ Completed: #{summary.completed_tasks} tasks
          ⚠️  Failed: #{summary.failed_tasks} tasks
          🚀 Deployed: #{summary.deployments} changes
          📈 Avg Confidence: #{summary.avg_confidence}%
          """),
          if length(summary.pending_questions || []) > 0 do
            text_section("""
            🤔 Waiting on your input:
            #{Enum.map_join(summary.pending_questions, "\n", &"• #{&1.question}")}
            """)
          end,
          if summary.top_recommendation do
            text_section("💡 Top recommendation: #{summary.top_recommendation}")
          end,
          button_section([
            {"📊 View Dashboard", "#{@web_url}/dashboard", :primary}
          ])
        ]
        |> Enum.reject(&is_nil/1)
    })
  end

  @doc "Notify about deployment"
  def deployment_notification(deployment) do
    status_emoji =
      case deployment.status do
        :success -> "✅"
        :failed -> "❌"
        :in_progress -> "⏳"
        _ -> "📦"
      end

    send_card(%{
      header: "#{status_emoji} Deployment #{deployment.status}",
      title: deployment.description || "Deployment",
      sections:
        [
          field_section([
            {"📦 Version", to_string(deployment.version)},
            {"⏱️ Time", relative_time(deployment.timestamp)},
            {"🎯 Confidence", "#{deployment.confidence || 0}%"}
          ]),
          if deployment.status == :failed && deployment.failure_reason do
            text_section("⚠️ Reason: #{deployment.failure_reason}")
          end
        ]
        |> Enum.reject(&is_nil/1)
    })
  end

  @doc "Notify about policy changes"
  def policy_change(change) do
    send_card(%{
      header: "⚙️ Policy Updated",
      title: "I adjusted deployment settings",
      sections: [
        text_section("""
        #{change.parameter}: #{change.old_value} → #{change.new_value}

        Reason: #{change.reason}
        """),
        field_section([
          {"📈 Recent success rate", "#{change.success_rate}%"},
          {"📊 Sample size", "#{change.sample_size} tasks"}
        ])
      ]
    })
  end

  ## Internal Functions

  defp send_card(card_data) do
    if is_nil(@webhook_url) do
      Logger.warning("Google Chat webhook URL not configured. Set GOOGLE_CHAT_WEBHOOK_URL")
      {:error, :no_webhook_url}
    else
      payload = build_payload(card_data)

      case Req.post(@webhook_url, json: payload) do
        {:ok, %{status: 200}} ->
          Logger.debug("Sent Google Chat notification")
          :ok

        {:error, error} ->
          Logger.error("Failed to send Google Chat notification: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_payload(card_data) do
    %{
      cardsV2: [
        %{
          cardId: "agent-card-#{:rand.uniform(999_999)}",
          card:
            %{
              header:
                if card_data[:header] do
                  %{
                    title: card_data.header,
                    imageUrl: "https://em-content.zobj.net/thumbs/120/google/350/robot_1f916.png",
                    imageType: "CIRCLE"
                  }
                end,
              sections: build_sections(card_data)
            }
            |> compact_map()
        }
      ]
    }
  end

  defp build_sections(card_data) do
    title_section =
      if card_data[:title] do
        [
          %{
            header: card_data.title,
            widgets:
              [
                if card_data[:subtitle] do
                  %{textParagraph: %{text: card_data.subtitle}}
                end
              ]
              |> Enum.reject(&is_nil/1)
          }
        ]
      else
        []
      end

    text_section =
      if card_data[:text] do
        [%{widgets: [%{textParagraph: %{text: card_data.text}}]}]
      else
        []
      end

    sections = card_data[:sections] || []

    title_section ++ text_section ++ sections
  end

  defp field_section(fields) do
    %{
      widgets:
        Enum.map(fields, fn {label, value} ->
          %{
            decoratedText: %{
              topLabel: label,
              text: to_string(value)
            }
          }
        end)
    }
  end

  defp text_section(text) do
    %{
      widgets: [
        %{
          textParagraph: %{text: text}
        }
      ]
    }
  end

  defp button_section(buttons) do
    %{
      widgets: [
        %{
          buttonList: %{
            buttons:
              Enum.map(buttons, fn {text, url, _style} ->
                %{
                  text: text,
                  onClick: %{
                    openLink: %{url: url}
                  }
                }
              end)
          }
        }
      ]
    }
  end

  defp urgency_text(:critical), do: "🚨 URGENT - Please respond ASAP"
  defp urgency_text(:high), do: "⚠️ High priority"
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
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join(", ")
  end

  defp format_context(_), do: ""

  defp compact_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
