defmodule Singularity.Workflows.DeadCodeReportWorkflow do
  @moduledoc """
  PGFlow Workflow Definition for Dead Code Monitoring Reports

  Replaces pgmq-based dead code report publishing with PGFlow workflow orchestration.
  Provides durable, observable dead code analysis reporting.

  Workflow Stages:
  1. Validate Report - Validate report structure and data
  2. Categorize Issues - Categorize dead code issues by severity
  3. Store Report - Persist report for historical tracking
  4. Notify Stakeholders - Send notifications to relevant systems
  5. Update Metrics - Update dead code monitoring metrics
  """

  use Pgflow.Workflow

  require Logger

  @doc """
  Define the dead code report workflow structure
  """
  def workflow_definition do
    %{
      name: "dead_code_report",
      version: Singularity.BuildInfo.version(),
      description: "Workflow for processing dead code monitoring reports",

      # Workflow-level configuration
      config: %{
        timeout_ms:
          Application.get_env(:singularity, :dead_code_report_workflow, %{})[:timeout_ms] ||
            45_000,
        retries:
          Application.get_env(:singularity, :dead_code_report_workflow, %{})[:retries] || 2,
        retry_delay_ms:
          Application.get_env(:singularity, :dead_code_report_workflow, %{})[:retry_delay_ms] ||
            3000,
        concurrency:
          Application.get_env(:singularity, :dead_code_report_workflow, %{})[:concurrency] ||
            3
      },

      # Define workflow steps
      steps: [
        %{
          id: :validate_report,
          name: "Validate Report",
          description: "Validate the structure and content of the dead code report",
          function: &__MODULE__.validate_report/1,
          timeout_ms: 5000,
          retry_count: 1
        },
        %{
          id: :categorize_issues,
          name: "Categorize Issues",
          description: "Categorize dead code issues by type and severity",
          function: &__MODULE__.categorize_issues/1,
          timeout_ms: 10000,
          retry_count: 1,
          depends_on: [:validate_report]
        },
        %{
          id: :store_report,
          name: "Store Report",
          description: "Persist the report for historical analysis and tracking",
          function: &__MODULE__.store_report/1,
          timeout_ms: 15000,
          retry_count: 2,
          depends_on: [:categorize_issues]
        },
        %{
          id: :notify_stakeholders,
          name: "Notify Stakeholders",
          description: "Send notifications to systems that need to be aware of dead code",
          function: &__MODULE__.notify_stakeholders/1,
          timeout_ms: 10000,
          retry_count: 1,
          depends_on: [:store_report]
        },
        %{
          id: :update_metrics,
          name: "Update Metrics",
          description: "Update dead code monitoring and quality metrics",
          function: &__MODULE__.update_metrics/1,
          timeout_ms: 5000,
          retry_count: 1,
          depends_on: [:store_report]
        }
      ]
    }
  end

  @doc """
  Validate the dead code report structure
  """
  def validate_report(%{"report" => report, "subject" => subject} = context) do
    required_fields = ["timestamp", "analysis_type"]
    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(report, &1)))

    if missing_fields != [] do
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    else
      Logger.debug("Dead code report validated",
        subject: subject,
        analysis_type: report["analysis_type"],
        timestamp: report["timestamp"]
      )

      {:ok, Map.put(context, "validated_report", report)}
    end
  end

  @doc """
  Categorize dead code issues by severity and type
  """
  def categorize_issues(%{"validated_report" => report} = context) do
    # Categorize based on subject pattern
    categories = %{
      "code_quality.dead_code.alert" => %{severity: :high, type: :alert},
      "code_quality.dead_code.weekly" => %{severity: :medium, type: :summary},
      "code_quality.dead_code.deep" => %{severity: :low, type: :analysis},
      "code_quality.dead_code.release_fail" => %{severity: :critical, type: :blocking},
      "code_quality.dead_code.release_pass" => %{severity: :info, type: :passing}
    }

    subject = Map.get(context, "subject", "")
    category = Map.get(categories, subject, %{severity: :unknown, type: :unknown})

    categorized_report =
      Map.merge(report, %{
        "category" => category,
        "categorized_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    Logger.debug("Dead code issues categorized",
      subject: subject,
      severity: category.severity,
      type: category.type
    )

    {:ok, Map.put(context, "categorized_report", categorized_report)}
  end

  @doc """
  Store the report for historical tracking
  """
  def store_report(%{"categorized_report" => report} = context) do
    subject = Map.get(context, "subject", "")
    analysis_type = report["analysis_type"]
    category = report["category"]
    severity = category["severity"]

    # Store to DeadCodeHistory for trend analysis
    alias Singularity.Schemas.DeadCodeHistory
    alias Singularity.Repo

    # Determine status from severity
    status =
      case severity do
        :critical -> "critical"
        :high -> "alert"
        :medium -> "warn"
        _ -> "ok"
      end

    # Count dead code items by category
    items = report["items"] || []
    total_count = length(items)

    history_attrs = %{
      check_date: DateTime.utc_now(),
      total_count: total_count,
      # Could calculate from previous check
      change_from_baseline: 0,
      status: status,
      triggered_by: "dead_code_workflow",
      output: Jason.encode!(report),
      notes: "Subject: #{subject}, Analysis: #{analysis_type}"
    }

    case %DeadCodeHistory{}
         |> DeadCodeHistory.changeset(history_attrs)
         |> Repo.insert() do
      {:ok, _history} ->
        Logger.info("Stored dead code report to history",
          subject: subject,
          total_count: total_count,
          status: status
        )

      {:error, changeset} ->
        Logger.error("Failed to store dead code report",
          subject: subject,
          errors: changeset.errors
        )
    end

    {:ok, Map.put(context, "report_stored", true)}
  end

  @doc """
  Notify stakeholders about the dead code report
  """
  def notify_stakeholders(%{"categorized_report" => report} = context) do
    subject = Map.get(context, "subject", "")
    severity = report["category"]["severity"]
    total_count = length(report["items"] || [])

    # Send notifications based on severity
    case severity do
      :critical ->
        Logger.warning("Critical dead code issue detected", subject: subject, count: total_count)
        # Send critical alerts via Telemetry
        :telemetry.execute(
          [:singularity, :dead_code, :alert, :critical],
          %{count: total_count},
          %{subject: subject, severity: :critical}
        )

      :high ->
        Logger.info("High-priority dead code alert", subject: subject, count: total_count)
        # Send high-priority alerts via Telemetry
        :telemetry.execute(
          [:singularity, :dead_code, :alert, :high],
          %{count: total_count},
          %{subject: subject, severity: :high}
        )

      _ ->
        Logger.debug("Dead code report processed", subject: subject)
    end

    {:ok, Map.put(context, "stakeholders_notified", true)}
  end

  @doc """
  Update dead code monitoring metrics
  """
  def update_metrics(%{"categorized_report" => report} = context) do
    subject = Map.get(context, "subject", "")
    severity = report["category"]["severity"]
    total_count = length(report["items"] || [])

    # Update metrics via Telemetry
    :telemetry.execute(
      [:singularity, :dead_code, :metrics, :update],
      %{count: total_count},
      %{subject: subject, severity: severity}
    )

    Logger.debug("Updated dead code metrics",
      subject: subject,
      severity: severity,
      count: total_count
    )

    {:ok, Map.put(context, "metrics_updated", true)}
  end
end
