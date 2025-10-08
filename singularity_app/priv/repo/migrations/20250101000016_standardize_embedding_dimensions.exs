defmodule Singularity.Repo.Migrations.StandardizeEmbeddingDimensions do
  use Ecto.Migration

  def up do
    # Optimize embedding dimensions for specific use cases:
    # - Code embeddings: 1536 dims (Qodo-Embed-1-1.5B) - richer representation for complex code
    # - Text embeddings: 1024 dims (Jina v3) - sufficient for documents, faster inference

    # Only alter tables that exist. Check table existence before altering.
    # Tables from schema: code_embeddings, code_locations, rag_documents, rag_queries,
    # semantic_cache, rules, knowledge_artifacts, technology_patterns

    # CODE EMBEDDINGS (1536 dims) - Qodo-Embed-1-1.5B for complex code representation
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='code_embeddings' AND column_name='embedding') THEN
        ALTER TABLE code_embeddings ALTER COLUMN embedding TYPE vector(1536);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='code_locations' AND column_name='embedding') THEN
        ALTER TABLE code_locations ALTER COLUMN embedding TYPE vector(1536);
      END IF;
    END $$;
    """

    # TEXT EMBEDDINGS (1024 dims) - Jina v3 for documents and knowledge
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='rag_documents' AND column_name='embedding') THEN
        ALTER TABLE rag_documents ALTER COLUMN embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='rag_queries' AND column_name='query_embedding') THEN
        ALTER TABLE rag_queries ALTER COLUMN query_embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='semantic_cache' AND column_name='query_embedding') THEN
        ALTER TABLE semantic_cache ALTER COLUMN query_embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='rules' AND column_name='embedding') THEN
        ALTER TABLE rules ALTER COLUMN embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='knowledge_artifacts' AND column_name='embedding') THEN
        ALTER TABLE knowledge_artifacts ALTER COLUMN embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='technology_patterns' AND column_name='embedding') THEN
        ALTER TABLE technology_patterns ALTER COLUMN embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='framework_patterns' AND column_name='embedding') THEN
        ALTER TABLE framework_patterns ALTER COLUMN embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='semantic_patterns' AND column_name='embedding') THEN
        ALTER TABLE semantic_patterns ALTER COLUMN embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='tool_knowledge' AND column_name='embeddings') THEN
        ALTER TABLE tool_knowledge ALTER COLUMN embeddings TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='external_package_registry' AND column_name='semantic_embedding') THEN
        ALTER TABLE external_package_registry ALTER COLUMN semantic_embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='external_package_registry' AND column_name='description_embedding') THEN
        ALTER TABLE external_package_registry ALTER COLUMN description_embedding TYPE vector(1024);
      END IF;
    END $$;
    """

    # CODE-RELATED PACKAGE EMBEDDINGS (1536 dims for code examples)
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='package_code_examples' AND column_name='code_embedding') THEN
        ALTER TABLE package_code_examples ALTER COLUMN code_embedding TYPE vector(1536);
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='package_usage_patterns' AND column_name='pattern_embedding') THEN
        ALTER TABLE package_usage_patterns ALTER COLUMN pattern_embedding TYPE vector(1536);
      END IF;
    END $$;
    """

    # Recreate vector indexes for optimized dimensions (only if tables exist)

    # CODE EMBEDDING INDEXES (1536 dims)
    execute "DROP INDEX IF EXISTS code_embeddings_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='code_embeddings') THEN
        CREATE INDEX code_embeddings_embedding_idx ON code_embeddings
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """

    execute "DROP INDEX IF EXISTS code_locations_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='code_locations') THEN
        CREATE INDEX code_locations_embedding_idx ON code_locations
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """

    # TEXT EMBEDDING INDEXES (1024 dims)
    execute "DROP INDEX IF EXISTS rag_documents_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='rag_documents') THEN
        CREATE INDEX rag_documents_embedding_idx ON rag_documents
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """

    execute "DROP INDEX IF EXISTS semantic_cache_query_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='semantic_cache') THEN
        CREATE INDEX semantic_cache_query_embedding_idx ON semantic_cache
        USING ivfflat (query_embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """

    execute "DROP INDEX IF EXISTS knowledge_artifacts_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='knowledge_artifacts') THEN
        CREATE INDEX knowledge_artifacts_embedding_idx ON knowledge_artifacts
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """

    execute "DROP INDEX IF EXISTS technology_patterns_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='technology_patterns') THEN
        CREATE INDEX technology_patterns_embedding_idx ON technology_patterns
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """

    execute "DROP INDEX IF EXISTS rules_embedding_idx"
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='rules') THEN
        CREATE INDEX rules_embedding_idx ON rules
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
      END IF;
    END $$;
    """
  end

  def down do
    # Revert to 768 dimensions (Google text-embedding-004)
    execute "ALTER TABLE code_embeddings ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE code_locations ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE rag_documents ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE rag_queries ALTER COLUMN query_embedding TYPE vector(768)"
    execute "ALTER TABLE semantic_cache ALTER COLUMN query_embedding TYPE vector(768)"
    execute "ALTER TABLE rules ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE knowledge_artifacts ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE dependency_catalog ALTER COLUMN semantic_embedding TYPE vector(768)"
    execute "ALTER TABLE dependency_catalog ALTER COLUMN description_embedding TYPE vector(768)"
    execute "ALTER TABLE code_examples ALTER COLUMN code_embedding TYPE vector(768)"
    execute "ALTER TABLE pattern_library ALTER COLUMN pattern_embedding TYPE vector(768)"
    execute "ALTER TABLE technology_patterns ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE git_commits ALTER COLUMN embedding TYPE vector(768)"
    execute "ALTER TABLE query_cache ALTER COLUMN query_embedding TYPE vector(768)"
    execute "ALTER TABLE codebase_metadata ALTER COLUMN vector_embedding TYPE vector(768)"
  end
end