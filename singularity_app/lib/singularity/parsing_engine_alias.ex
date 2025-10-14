defmodule Singularity.ParsingEngine do
  @moduledoc """
  Compatibility wrapper that exposes the parsing engine under the
  `Singularity.ParsingEngine` name. Delegates to `Singularity.Engines.ParserEngine`.
  """

  defdelegate parse_and_store_file(path, opts \\ []), to: Singularity.Engines.ParserEngine
  defdelegate parse_and_store_tree(root, opts \\ []), to: Singularity.Engines.ParserEngine
  defdelegate parse_file(path), to: Singularity.Engines.ParserEngine
  defdelegate parse_tree(root), to: Singularity.Engines.ParserEngine
  defdelegate parse_files(paths), to: Singularity.Engines.ParserEngine
  defdelegate parse_tree_by_language(root, language), to: Singularity.Engines.ParserEngine
  defdelegate extract_functions(path), to: Singularity.Engines.ParserEngine
  defdelegate extract_classes(path), to: Singularity.Engines.ParserEngine
  defdelegate extract_imports(path), to: Singularity.Engines.ParserEngine
  defdelegate extract_exports(path), to: Singularity.Engines.ParserEngine
  defdelegate extract_symbols(path), to: Singularity.Engines.ParserEngine
  defdelegate extract_ast(path), to: Singularity.Engines.ParserEngine
  defdelegate extract_all_functions(paths), to: Singularity.Engines.ParserEngine
  defdelegate extract_all_classes(paths), to: Singularity.Engines.ParserEngine
  defdelegate find_dependencies(path), to: Singularity.Engines.ParserEngine
  defdelegate detect_language(path), to: Singularity.Engines.ParserEngine
end
