use std::{path::Path, sync::Arc};

use tree_sitter::Language;

use crate::{
  macros::{get_language, mk_action, mk_code, mk_emacs_mode, mk_extensions, mk_lang, mk_langs},
  preproc::PreprocResults,
  *,
};

mk_langs!(
  // 1) Name for enum
  // 2) Language description
  // 3) Display name
  // 4) Empty struct name to implement
  // 5) Parser name
  // 6) tree-sitter function to call to get a Language
  // 7) file extensions
  // 8) emacs modes
  // Mozilla JS removed - using standard JavaScript parser
  // (
  //     Mozjs,
  //     "The `Mozjs` language is variant of the `JavaScript` language",
  //     "javascript",
  //     MozjsCode,
  //     MozjsParser,
  //     tree_sitter_mozjs,
  //     [js, jsm, mjs, jsx],
  //     ["js", "js2"]
  // ),
  (Javascript, "The `JavaScript` language", "javascript", JavascriptCode, JavascriptParser, tree_sitter_javascript, [], []),
  (Java, "The `Java` language", "java", JavaCode, JavaParser, tree_sitter_java, [java], ["java"]),
  // Kotlin temporarily disabled - different tree-sitter interface (uses language() function instead of LANGUAGE)
  // (
  //     Kotlin,
  //     "The `Kotlin` language",
  //     "kotlin",
  //     KotlinCode,
  //     KotlinParser,
  //     tree_sitter_kotlin,
  //     [kt, kts],
  //     ["kotlin"]
  // ),
  (Rust, "The `Rust` language", "rust", RustCode, RustParser, tree_sitter_rust, [rs], ["rust"]),
  (
    Cpp,
    "The `C/C++` language",
    "c/c++",
    CppCode,
    CppParser,
    tree_sitter_cpp,
    [cpp, cxx, cc, hxx, hpp, c, h, hh, inc, mm, m],
    ["c++", "c", "objc", "objc++", "objective-c++", "objective-c"]
  ),
  (Python, "The `Python` language", "python", PythonCode, PythonParser, tree_sitter_python, [py], ["python"]),
  (Tsx, "The `Tsx` language incorporates the `JSX` syntax inside `TypeScript`", "typescript", TsxCode, TsxParser, tree_sitter_tsx, [tsx], []),
  (Typescript, "The `TypeScript` language", "typescript", TypescriptCode, TypescriptParser, tree_sitter_typescript, [ts, jsw, jsmw], ["typescript"]) /* Mozilla custom parsers removed - using standard tree-sitter parsers only
                                                                                                                                                      * - Ccomment: Use standard C/C++ parser for comment analysis
                                                                                                                                                      * - Preproc: Use standard C/C++ parser for macro analysis */
);

// Compatibility structs for Mozilla custom parsers - functionality delegated to standard parsers
pub struct MozjsCode;
pub struct PreprocCode;
pub struct CcommentCode;
pub struct KotlinCode;

// Compatibility parser types - delegate to standard parsers
pub type MozjsParser = JavascriptParser;
pub type PreprocParser = CppParser;
pub type CcommentParser = CppParser;
pub type KotlinParser = JavaParser; // Use Java parser as fallback for Kotlin

pub(crate) mod fake {
  pub(crate) fn get_true<'a>(ext: &str, mode: &str) -> Option<&'a str> {
    if ext == "m" || ext == "mm" || mode == "objc" || mode == "objc++" || mode == "objective-c++" || mode == "objective-c" {
      Some("obj-c/c++")
    } else {
      None
    }
  }
}
