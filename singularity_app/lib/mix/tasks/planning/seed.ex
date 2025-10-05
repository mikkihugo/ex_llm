defmodule Mix.Tasks.Planning.Seed do
  @moduledoc """
  Seeds the work plan database with Singularity roadmap data.

  ## Usage

      mix planning.seed

  This will:
  1. Clear existing work plan data (strategic themes, epics, capabilities, features)
  2. Load seed data from priv/repo/seeds/work_plan_seeds.exs
  3. Display summary of loaded data

  ## Options

      --quiet  - Suppress output messages

  ## Examples

      # Standard seeding
      mix planning.seed

      # Quiet mode
      mix planning.seed --quiet
  """

  use Mix.Task

  @shortdoc "Seeds the work plan database with Singularity roadmap"

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [quiet: :boolean])

    unless opts[:quiet] do
      Mix.shell().info("Seeding work plan database...")
    end

    seed_file = Path.join(:code.priv_dir(:singularity_app), "repo/seeds/work_plan_seeds.exs")

    if File.exists?(seed_file) do
      Code.eval_file(seed_file)

      unless opts[:quiet] do
        Mix.shell().info("Work plan seeded successfully!")
      end
    else
      Mix.shell().error("Seed file not found: #{seed_file}")
      Mix.shell().error("Please create the seed file or check the path.")
    end
  end
end
