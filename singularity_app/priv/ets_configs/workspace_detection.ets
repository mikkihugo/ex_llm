# ETS table for workspace detection templates
# This is a test file - in production, this comes from central NATS

[
  {
    "rust-cargo-workspace",
    %{
      "type" => "workspace_pattern",
      "detection" => %{
        "indicators" => [
          "Cargo.toml with [workspace] section",
          "Multiple Cargo.toml files in subdirectories",
          "workspace.members array in root Cargo.toml"
        ],
        "confidence_threshold" => 0.8
      },
      "structure" => %{
        "root_files" => ["Cargo.toml", "Cargo.lock"],
        "workspace_members" => ["crates/*", "apps/*", "libs/*"],
        "common_directories" => ["crates/", "apps/", "libs/", "examples/", "tests/", "benches/"]
      },
      "commands" => %{
        "build" => ["cargo build", "cargo build --workspace"],
        "test" => ["cargo test", "cargo test --workspace"],
        "lint" => ["cargo clippy", "cargo clippy --workspace"],
        "format" => ["cargo fmt", "cargo fmt --all"]
      },
      "naming_conventions" => %{
        "crates" => "kebab-case",
        "modules" => "snake_case",
        "functions" => "snake_case",
        "structs" => "PascalCase",
        "enums" => "PascalCase"
      }
    }
  },
  {
    "node-npm-workspace",
    %{
      "type" => "workspace_pattern",
      "detection" => %{
        "indicators" => [
          "package.json with workspaces field",
          "Multiple package.json files in subdirectories",
          "node_modules/.pnpm directory (if using pnpm)"
        ],
        "confidence_threshold" => 0.8
      },
      "structure" => %{
        "root_files" => ["package.json", "package-lock.json"],
        "workspace_members" => ["packages/*", "apps/*", "libs/*"],
        "common_directories" => ["packages/", "apps/", "libs/", "tools/", "docs/"]
      },
      "commands" => %{
        "build" => ["npm run build", "npm run build --workspaces"],
        "test" => ["npm test", "npm test --workspaces"],
        "lint" => ["npm run lint", "npm run lint --workspaces"],
        "format" => ["npm run format", "npm run format --workspaces"]
      },
      "naming_conventions" => %{
        "packages" => "kebab-case",
        "files" => "kebab-case",
        "functions" => "camelCase",
        "classes" => "PascalCase",
        "variables" => "camelCase"
      }
    }
  },
  {
    "deno-workspace",
    %{
      "type" => "workspace_pattern",
      "detection" => %{
        "indicators" => [
          "deno.json with workspaces field",
          "Multiple deno.json files in subdirectories",
          "import_map.json files",
          "deno.lock file"
        ],
        "confidence_threshold" => 0.8
      },
      "structure" => %{
        "root_files" => ["deno.json", "deno.lock", "import_map.json"],
        "workspace_members" => ["apps/*", "libs/*", "packages/*"],
        "common_directories" => ["apps/", "libs/", "packages/", "tools/", "docs/"]
      },
      "commands" => %{
        "build" => ["deno task build", "deno build"],
        "test" => ["deno test", "deno test --workspace"],
        "lint" => ["deno lint", "deno lint --workspace"],
        "format" => ["deno fmt", "deno fmt --workspace"]
      },
      "naming_conventions" => %{
        "modules" => "kebab-case",
        "files" => "kebab-case",
        "functions" => "camelCase",
        "classes" => "PascalCase",
        "interfaces" => "PascalCase"
      }
    }
  }
]