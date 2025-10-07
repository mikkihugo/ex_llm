defmodule Singularity.Repo.Migrations.StandardizeEmbeddingDimensions do
  use Ecto.Migration

  def up do
    # Optimize embedding dimensions for specific use cases:
    # - Code embeddings: 1536 dims (Qodo-Embed-1-1.5B) - richer representation for complex code
    # - Text embeddings: 1024 dims (Jina v3) - sufficient for documents, faster inference
    
    # CODE EMBEDDINGS (1536 dims) - Qodo-Embed-1-1.5B for complex code representation
    execute "ALTER TABLE code_embeddings ALTER COLUMN embedding TYPE vector(1536)"
    execute "ALTER TABLE code_locations ALTER COLUMN embedding TYPE vector(1536)"
    execute "ALTER TABLE codebase_metadata ALTER COLUMN vector_embedding TYPE vector(1536)"
    execute "ALTER TABLE graph_nodes ALTER COLUMN vector_embedding TYPE vector(1536)"
    execute "ALTER TABLE vector_search ALTER COLUMN vector_embedding TYPE vector(1536)"
    
    # TEXT EMBEDDINGS (1024 dims) - Jina v3 for documents and knowledge
    execute "ALTER TABLE rag_documents ALTER COLUMN embedding TYPE vector(1024)"
    execute "ALTER TABLE rag_queries ALTER COLUMN query_embedding TYPE vector(1024)"
    execute "ALTER TABLE semantic_cache ALTER COLUMN query_embedding TYPE vector(1024)"
    execute "ALTER TABLE rules ALTER COLUMN embedding TYPE vector(1024)"
    execute "ALTER TABLE knowledge_artifacts ALTER COLUMN embedding TYPE vector(1024)"
    execute "ALTER TABLE git_commits ALTER COLUMN embedding TYPE vector(1024)"
    
    # TECHNOLOGY DETECTION (text-based)
    execute "ALTER TABLE technology_patterns ALTER COLUMN embedding TYPE vector(1024)"
    
    # TEMPLATES (1536 dims for code templates)
    execute "ALTER TABLE templates ALTER COLUMN embedding TYPE vector(1536)"
    
    # Recreate vector indexes for optimized dimensions
    
    # CODE EMBEDDING INDEXES (1536 dims)
    execute "DROP INDEX IF EXISTS code_embeddings_embedding_idx"
    execute "CREATE INDEX code_embeddings_embedding_idx ON code_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS code_locations_embedding_idx"
    execute "CREATE INDEX code_locations_embedding_idx ON code_locations USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS codebase_metadata_vector_embedding_idx"
    execute "CREATE INDEX codebase_metadata_vector_embedding_idx ON codebase_metadata USING ivfflat (vector_embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS graph_nodes_vector_embedding_idx"
    execute "CREATE INDEX graph_nodes_vector_embedding_idx ON graph_nodes USING ivfflat (vector_embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS vector_search_vector_embedding_idx"
    execute "CREATE INDEX vector_search_vector_embedding_idx ON vector_search USING ivfflat (vector_embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS templates_embedding_idx"
    execute "CREATE INDEX templates_embedding_idx ON templates USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    # TEXT EMBEDDING INDEXES (1024 dims)
    execute "DROP INDEX IF EXISTS rag_documents_embedding_idx"
    execute "CREATE INDEX rag_documents_embedding_idx ON rag_documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS semantic_cache_query_embedding_idx"
    execute "CREATE INDEX semantic_cache_query_embedding_idx ON semantic_cache USING ivfflat (query_embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS knowledge_artifacts_embedding_idx"
    execute "CREATE INDEX knowledge_artifacts_embedding_idx ON knowledge_artifacts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS technology_patterns_embedding_idx"
    execute "CREATE INDEX technology_patterns_embedding_idx ON technology_patterns USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS rules_embedding_idx"
    execute "CREATE INDEX rules_embedding_idx ON rules USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    
    execute "DROP INDEX IF EXISTS git_commits_embedding_idx"
    execute "CREATE INDEX git_commits_embedding_idx ON git_commits USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
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