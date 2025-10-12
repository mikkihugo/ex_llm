IO.puts("Testing NIF loading...")
try do
  result = Singularity.EmbeddingEngine.embed("test text", model: :qodo_embed)
  IO.inspect(result)
  IO.puts("NIF loaded successfully!")
rescue
  error -> 
    IO.puts("NIF not loaded: #{inspect(error)}")
end
