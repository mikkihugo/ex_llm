# Procfile for fly.io multi-process deployment
# Fly.io will run these processes based on the process name in fly.toml

web: mix phx.server
ai-server: cd ai-server && bun run src/server.ts
