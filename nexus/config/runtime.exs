import Config

# The secret key base is used to sign/encrypt tokens and other secrets.
# If you do not have one, you can generate one by calling: mix phx.gen.secret
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :nexus, NexusWeb.Endpoint,
  secret_key_base: secret_key_base

# NATS configuration
nats_host = System.get_env("NATS_HOST", "127.0.0.1")
nats_port = String.to_integer(System.get_env("NATS_PORT", "4222"))

config :gnat,
  host: String.to_charlist(nats_host),
  port: nats_port
