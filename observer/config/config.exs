# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :observer,
  ecto_repos: [Observer.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :observer, ObserverWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: ObserverWeb.ErrorHTML, json: ObserverWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Observer.PubSub,
  live_view: [signing_salt: "OMPDJ79z"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :observer, Observer.Mailer, adapter: Swoosh.Adapters.Local

# Shared job & queue infrastructure
config :observer, Oban,
  repo: Observer.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 5]

config :observer, :pgmq,
  repo: Observer.Repo,
  table_prefix: "pgmq"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
