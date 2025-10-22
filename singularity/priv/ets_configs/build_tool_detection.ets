# ETS table for build tool detection
# This is a test file - in production, this comes from central NATS

[
  {
    "npm",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "package.json"},
        %{"type" => "file", "path" => "package-lock.json"}
      ],
      "tools" => ["npm"],
      "managers" => ["npm"]
    }
  },
  {
    "yarn",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "yarn.lock"},
        %{"type" => "file", "path" => "package.json"}
      ],
      "tools" => ["yarn"],
      "managers" => ["yarn"]
    }
  },
  {
    "pnpm",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "pnpm-lock.yaml"},
        %{"type" => "file", "path" => "pnpm-workspace.yaml"}
      ],
      "tools" => ["pnpm"],
      "managers" => ["pnpm"]
    }
  },
  {
    "bun",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "bun.lockb"},
        %{"type" => "file", "path" => "bunfig.toml"}
      ],
      "tools" => ["bun"],
      "managers" => ["bun"]
    }
  },
  {
    "cargo",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "Cargo.toml"},
        %{"type" => "file", "path" => "Cargo.lock"}
      ],
      "tools" => ["cargo"],
      "managers" => ["cargo"]
    }
  },
  {
    "mix",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "mix.exs"},
        %{"type" => "file", "path" => "mix.lock"}
      ],
      "tools" => ["mix"],
      "managers" => ["hex"]
    }
  },
  {
    "rebar",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "rebar.config"},
        %{"type" => "file", "path" => "rebar.lock"}
      ],
      "tools" => ["rebar3"],
      "managers" => ["rebar3"]
    }
  },
  {
    "gleam",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "gleam.toml"},
        %{"type" => "file", "path" => "gleam.lock"}
      ],
      "tools" => ["gleam"],
      "managers" => ["gleam"]
    }
  },
  {
    "deno",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "deno.json"},
        %{"type" => "file", "path" => "deno.lock"}
      ],
      "tools" => ["deno"],
      "managers" => ["deno"]
    }
  },
  {
    "go",
    %{
      "type" => "build_tool_detection",
      "indicators" => [
        %{"type" => "file", "path" => "go.mod"},
        %{"type" => "file", "path" => "go.sum"}
      ],
      "tools" => ["go"],
      "managers" => ["go"]
    }
  }
]