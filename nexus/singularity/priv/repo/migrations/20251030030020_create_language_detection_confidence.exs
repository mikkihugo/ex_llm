defmodule Singularity.Repo.Migrations.CreateLanguageDetectionConfidence do
  use Ecto.Migration

  def change do
    create table(:language_detection_confidence) do
      add :detection_method, :string, null: false  # "extension", "manifest", "filename"
      add :language_id, :string, null: false       # "rust", "elixir", "javascript", etc.
      add :pattern, :string, null: false           # "*.rs", "Cargo.toml", "Dockerfile", etc.
      add :confidence_score, :float, default: 0.5, null: false  # Learned confidence 0.0-1.0
      add :detection_count, :integer, default: 0, null: false   # Total detections attempted
      add :success_count, :integer, default: 0, null: false     # Successful detections
      add :success_rate, :float, default: 0.0, null: false      # success_count / detection_count
      add :last_updated_at, :utc_datetime_usec, null: false
      add :metadata, :map, default: %{}, null: false           # Additional context

      timestamps()
    end

    # Indexes for efficient lookups
    create index(:language_detection_confidence, [:detection_method, :language_id])
    create index(:language_detection_confidence, [:pattern])
    create unique_index(:language_detection_confidence, [:detection_method, :pattern, :language_id],
                        name: :unique_detection_method_pattern)

    # Insert default confidence values (will be learned/adapted over time)
    execute """
    INSERT INTO language_detection_confidence
    (detection_method, language_id, pattern, confidence_score, detection_count, success_count, success_rate, last_updated_at, inserted_at, updated_at)
    VALUES
    -- Extension-based detection (very reliable)
    ('extension', 'rust', '*.rs', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'elixir', '*.ex', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'elixir', '*.exs', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'javascript', '*.js', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'typescript', '*.ts', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'python', '*.py', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'go', '*.go', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'java', '*.java', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'csharp', '*.cs', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'cpp', '*.cpp', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'cpp', '*.cc', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'cpp', '*.cxx', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'erlang', '*.erl', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('extension', 'gleam', '*.gleam', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),

    -- Manifest-based detection (reliable but contextual)
    ('manifest', 'rust', 'Cargo.toml', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'elixir', 'mix.exs', 0.99, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'javascript', 'package.json', 0.90, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'typescript', 'package.json', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()), -- with tsconfig.json
    ('manifest', 'python', 'pyproject.toml', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'python', 'setup.py', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'go', 'go.mod', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'java', 'pom.xml', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'java', 'build.gradle', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'erlang', 'rebar.config', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'ruby', 'Gemfile', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('manifest', 'php', 'composer.json', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),

    -- Filename-based detection (specific cases)
    ('filename', 'dockerfile', 'Dockerfile', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW()),
    ('filename', 'dockerfile', 'dockerfile', 0.95, 0, 0, 0.0, NOW(), NOW(), NOW())
    ON CONFLICT (detection_method, pattern, language_id) DO NOTHING;
    """
  end
end
