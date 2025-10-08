use regex::Regex;

// Extract imports/dependencies for BEAM languages using lightweight regexes.

pub fn extract_elixir_deps(content: &str) -> Vec<String> {
  let mut deps = Vec::new();

  // alias Foo.Bar
  let re_alias_simple = Regex::new(r"(?m)^\s*alias\s+([A-Z][A-Za-z0-9_.]*)").unwrap();
  for cap in re_alias_simple.captures_iter(content) {
    deps.push(cap[1].to_string());
  }

  // alias Foo.Bar.{Baz, Qux}
  let re_alias_multi = Regex::new(r"(?m)^\s*alias\s+([A-Z][A-Za-z0-9_]*)\.([A-Za-z0-9_]+)\.\{([^}]+)\}").unwrap();
  for cap in re_alias_multi.captures_iter(content) {
    let prefix = format!("{}.{}", &cap[1], &cap[2]);
    for part in cap[3].split(',') {
      let name = part.trim().trim_matches('_');
      if name.is_empty() { continue; }
      deps.push(format!("{}.{}", prefix, name));
    }
  }

  // import/require/use Module
  let re_iru = Regex::new(r"(?m)^\s*(import|require|use)\s+([A-Z][A-Za-z0-9_.]*)").unwrap();
  for cap in re_iru.captures_iter(content) {
    deps.push(cap[2].to_string());
  }

  deps.sort();
  deps.dedup();
  deps
}

pub fn extract_erlang_deps(content: &str) -> Vec<String> {
  let mut deps = Vec::new();

  // -import(mod, [fun/arity, ...]).
  let re_import = Regex::new(r"(?m)^\s*-import\(\s*([a-z][a-z0-9_]*)\s*,\s*\[").unwrap();
  for cap in re_import.captures_iter(content) {
    deps.push(cap[1].to_string());
  }

  // -include("file.hrl"). and -include_lib("app/include/file.hrl").
  let re_include = Regex::new(r#"(?m)^\s*-include(_lib)?\(\s*\"([^\"]+)\"\s*\)\s*\."#).unwrap();
  for cap in re_include.captures_iter(content) {
    deps.push(cap[2].to_string());
  }

  // -behaviour(gen_server).
  let re_beh = Regex::new(r"(?m)^\s*-behaviou?r\(\s*([a-z][a-z0-9_]*)\s*\)\s*\.").unwrap();
  for cap in re_beh.captures_iter(content) {
    deps.push(cap[1].to_string());
  }

  deps.sort();
  deps.dedup();
  deps
}

pub fn extract_gleam_deps(content: &str) -> Vec<String> {
  let mut deps = Vec::new();

  // import pkg/module as Alias exposing (..)
  let re_import = Regex::new(r"(?m)^\s*import\s+([a-z0-9_]+(?:/[a-z0-9_]+)*)").unwrap();
  for cap in re_import.captures_iter(content) {
    deps.push(cap[1].to_string());
  }

  deps.sort();
  deps.dedup();
  deps
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn elixir_alias_and_imports() {
    let code = r#"
alias Foo.Bar
alias My.App.{Repo, User}
require Logger
use Plug.Conn
import My.Helpers
"#;
    let d = extract_elixir_deps(code);
    assert!(d.contains(&"Foo.Bar".to_string()));
    assert!(d.contains(&"My.App.Repo".to_string()));
    assert!(d.contains(&"My.App.User".to_string()));
    assert!(d.contains(&"Plug.Conn".to_string()));
  }

  #[test]
  fn erlang_import_include_behaviour() {
    let code = r#"
-module(sample).
-import(lists, [map/2, foldl/3]).
-include("sample.hrl").
-include_lib("kernel/include/file.hrl").
-behaviour(gen_server).
"#;
    let d = extract_erlang_deps(code);
    assert!(d.contains(&"lists".to_string()));
    assert!(d.contains(&"sample.hrl".to_string()));
    assert!(d.contains(&"kernel/include/file.hrl".to_string()));
    assert!(d.contains(&"gen_server".to_string()));
  }

  #[test]
  fn gleam_imports() {
    let code = r#"
import gleam/io
import project/utils as Utils exposing (..)
"#;
    let d = extract_gleam_deps(code);
    assert!(d.contains(&"gleam/io".to_string()));
    assert!(d.contains(&"project/utils".to_string()));
  }
}

