import Config

# Configure the database
config :central_cloud, CentralCloud.Repo,
  database: "central_services",
  hostname: "localhost",
  port: 5432,
  username: "mhugo",
  password: "",
  pool_size: 10

# Configure NATS
config :central_cloud, CentralCloud.NatsClient,
  host: "localhost",
  port: 4222

# Configure logging
config :logger, level: :info

# Ensure the repo is configured for the application
config :central_cloud, ecto_repos: [CentralCloud.Repo]