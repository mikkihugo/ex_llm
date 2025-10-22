import Config

# Configure the database
config :centralcloud, Centralcloud.Repo,
  database: "centralcloud",
  hostname: System.get_env("CENTRALCLOUD_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("CENTRALCLOUD_DB_PORT", "5432")),
  username: System.get_env("CENTRALCLOUD_DB_USER", "mhugo"),
  password: System.get_env("CENTRALCLOUD_DB_PASSWORD", ""),
  pool_size: 10

# Configure NATS
config :centralcloud, Centralcloud.NatsClient,
  host: System.get_env("NATS_HOST", "localhost"),
  port: String.to_integer(System.get_env("NATS_PORT", "4222"))

# Configure the application
config :centralcloud,
  ecto_repos: [Centralcloud.Repo]

import_config "#{config_env()}.exs"