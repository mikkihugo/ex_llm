use crate::{
  metrics::halstead::HalsteadType, spaces::SpaceKind, traits::Search, CcommentCode, Cpp, CppCode, ElixirCode, ErlangCode, GleamCode, Java, JavaCode, Javascript, JavascriptCode, KotlinCode,
  Lua, LuaCode, Mozjs, MozjsCode, Node, PreprocCode, Python, PythonCode, Rust, RustCode, Tsx, TsxCode, Typescript, TypescriptCode,
};

macro_rules! get_operator {
  ($language:ident) => {
    #[inline(always)]
    fn get_operator_id_as_str(id: u16) -> &'static str {
      let typ = id.into();
      match typ {
        $language::LPAREN => "()",
        $language::LBRACK => "[]",
        $language::LBRACE => "{}",
        _ => typ.into(),
      }
    }
  };
}

pub trait Getter {
  fn get_func_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    Self::get_func_space_name(node, code)
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    // we're in a function or in a class
    node.child_by_field_name("name").map_or(Some("<anonymous>"), |name| {
      let code = &code[name.start_byte()..name.end_byte()];
      std::str::from_utf8(code).ok()
    })
  }

  fn get_space_kind(_node: &Node) -> SpaceKind {
    SpaceKind::Unknown
  }

  fn get_op_type(_node: &Node) -> HalsteadType {
    HalsteadType::Unknown
  }

  fn get_operator_id_as_str(_id: u16) -> &'static str {
    ""
  }
}

impl Getter for PythonCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    match node.kind_id().into() {
      Python::FunctionDefinition => SpaceKind::Function,
      Python::ClassDefinition => SpaceKind::Class,
      Python::Module => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Python::{
      And, As, Assert, Async, Await, Await2, Break, Continue, Def, Del, Elif, Else, Except, Exec, ExpressionStatement, False, Finally, Float, For, From,
      Global, Identifier, If, Import, In, Integer, Is, None, Not, Or, Pass, Print, Raise, Return, String, True, Try, While, With, Yield, AMP, AMPEQ, AT, ATEQ,
      BANGEQ, CARET, CARETEQ, COLONEQ, COMMA, DASH, DASHEQ, DASHGT, DOT, EQ, EQEQ, GT, GTEQ, GTGT, GTGTEQ, LT, LTEQ, LTGT, LTLT, LTLTEQ, PERCENT, PERCENTEQ,
      PIPE, PIPEEQ, PLUS, PLUSEQ, SLASH, SLASHEQ, SLASHSLASH, SLASHSLASHEQ, STAR, STAREQ, STARSTAR, STARSTAREQ, TILDE,
    };

    match node.kind_id().into() {
      Import | DOT | From | COMMA | As | STAR | GTGT | Assert | COLONEQ | Return | Def | Del | Raise | Pass | Break | Continue | If | Elif | Else | Async
      | For | In | While | Try | Except | Finally | With | DASHGT | EQ | Global | Exec | AT | Not | And | Or | PLUS | DASH | SLASH | PERCENT | SLASHSLASH
      | STARSTAR | PIPE | AMP | CARET | LTLT | TILDE | LT | LTEQ | EQEQ | BANGEQ | GTEQ | GT | LTGT | Is | PLUSEQ | DASHEQ | STAREQ | SLASHEQ | ATEQ
      | SLASHSLASHEQ | PERCENTEQ | STARSTAREQ | GTGTEQ | LTLTEQ | AMPEQ | CARETEQ | PIPEEQ | Yield | Await | Await2 | Print => HalsteadType::Operator,
      Identifier | Integer | Float | True | False | None => HalsteadType::Operand,
      String => {
        let mut operator = HalsteadType::Unknown;
        // check if we've a documentation string or a multiline comment
        if let Some(parent) = node.parent() {
          if parent.kind_id() != ExpressionStatement || parent.child_count() != 1 {
            operator = HalsteadType::Operand;
          }
        }
        operator
      }
      _ => HalsteadType::Unknown,
    }
  }

  fn get_operator_id_as_str(id: u16) -> &'static str {
    Into::<Python>::into(id).into()
  }
}

// Singularity custom parsers - delegate to standard parsers for compatibility
impl Getter for MozjsCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    JavascriptCode::get_space_kind(node)
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    JavascriptCode::get_func_space_name(node, code)
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    JavascriptCode::get_op_type(node)
  }

  fn get_operator_id_as_str(id: u16) -> &'static str {
    JavascriptCode::get_operator_id_as_str(id)
  }
}

impl Getter for JavascriptCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    use Javascript::{
      ArrowFunction, Class, ClassDeclaration, FunctionDeclaration, FunctionExpression, GeneratorFunction, GeneratorFunctionDeclaration, MethodDefinition,
      Program,
    };

    match node.kind_id().into() {
      FunctionExpression | MethodDefinition | GeneratorFunction | FunctionDeclaration | GeneratorFunctionDeclaration | ArrowFunction => SpaceKind::Function,
      Class | ClassDeclaration => SpaceKind::Class,
      Program => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    if let Some(name) = node.child_by_field_name("name") {
      let code = &code[name.start_byte()..name.end_byte()];
      std::str::from_utf8(code).ok()
    } else {
      // We can be in a pair: foo: function() {}
      // Or in a variable declaration: var aFun = function() {}
      if let Some(parent) = node.parent() {
        match parent.kind_id().into() {
          Mozjs::Pair => {
            if let Some(name) = parent.child_by_field_name("key") {
              let code = &code[name.start_byte()..name.end_byte()];
              return std::str::from_utf8(code).ok();
            }
          }
          Mozjs::VariableDeclarator => {
            if let Some(name) = parent.child_by_field_name("name") {
              let code = &code[name.start_byte()..name.end_byte()];
              return std::str::from_utf8(code).ok();
            }
          }
          _ => {}
        }
      }
      Some("<anonymous>")
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Javascript::{
      As, Async, Await, Break, Case, Catch, Const, Continue, Default, Delete, Else, Export, Extends, False, Finally, For, From, Function, FunctionExpression,
      Get, Identifier, Identifier2, If, Import, Import2, In, Instanceof, Let, MemberExpression, MemberExpression2, New, Null, Number, Of, PropertyIdentifier,
      Return, Set, String, String2, Super, Switch, This, Throw, True, Try, Typeof, Undefined, Var, Void, While, With, Yield, AMP, AMPAMP, AMPEQ, AT, BANG,
      BANGEQ, BANGEQEQ, CARET, CARETEQ, COLON, COMMA, DASH, DASHDASH, DASHEQ, DOT, EQ, EQEQ, EQEQEQ, GT, GTEQ, GTGT, GTGTEQ, GTGTGT, GTGTGTEQ, LBRACE, LBRACK,
      LPAREN, LT, LTEQ, LTLT, LTLTEQ, PERCENT, PERCENTEQ, PIPE, PIPEEQ, PIPEPIPE, PLUS, PLUSEQ, PLUSPLUS, QMARK, QMARKQMARK, SEMI, SLASH, SLASHEQ, STAR,
      STAREQ, STARSTAR, STARSTAREQ, TILDE,
    };

    match node.kind_id().into() {
      Export | Import | Import2 | Extends | DOT | From | LPAREN | COMMA | As | STAR | GTGT | GTGTGT | COLON | Return | Delete | Throw | Break | Continue
      | If | Else | Switch | Case | Default | Async | For | In | Of | While | Try | Catch | Finally | With | EQ | AT | AMPAMP | PIPEPIPE | PLUS | DASH
      | DASHDASH | PLUSPLUS | SLASH | PERCENT | STARSTAR | PIPE | AMP | LTLT | TILDE | LT | LTEQ | EQEQ | BANGEQ | GTEQ | GT | PLUSEQ | BANG | BANGEQEQ
      | EQEQEQ | DASHEQ | STAREQ | SLASHEQ | PERCENTEQ | STARSTAREQ | GTGTEQ | GTGTGTEQ | LTLTEQ | AMPEQ | CARET | CARETEQ | PIPEEQ | Yield | LBRACK
      | LBRACE | Await | QMARK | QMARKQMARK | New | Let | Var | Const | Function | FunctionExpression | SEMI => HalsteadType::Operator,
      Identifier | Identifier2 | MemberExpression | MemberExpression2 | PropertyIdentifier | String | String2 | Number | True | False | Null | Void | This
      | Super | Undefined | Set | Get | Typeof | Instanceof => HalsteadType::Operand,
      _ => HalsteadType::Unknown,
    }
  }

  get_operator!(Javascript);
}

impl Getter for TypescriptCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    use Typescript::{
      ArrowFunction, Class, ClassDeclaration, FunctionDeclaration, FunctionExpression, GeneratorFunction, GeneratorFunctionDeclaration, InterfaceDeclaration,
      MethodDefinition, Program,
    };

    match node.kind_id().into() {
      FunctionExpression | MethodDefinition | GeneratorFunction | FunctionDeclaration | GeneratorFunctionDeclaration | ArrowFunction => SpaceKind::Function,
      Class | ClassDeclaration => SpaceKind::Class,
      InterfaceDeclaration => SpaceKind::Interface,
      Program => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    if let Some(name) = node.child_by_field_name("name") {
      let code = &code[name.start_byte()..name.end_byte()];
      std::str::from_utf8(code).ok()
    } else {
      // We can be in a pair: foo: function() {}
      // Or in a variable declaration: var aFun = function() {}
      if let Some(parent) = node.parent() {
        match parent.kind_id().into() {
          Mozjs::Pair => {
            if let Some(name) = parent.child_by_field_name("key") {
              let code = &code[name.start_byte()..name.end_byte()];
              return std::str::from_utf8(code).ok();
            }
          }
          Mozjs::VariableDeclarator => {
            if let Some(name) = parent.child_by_field_name("name") {
              let code = &code[name.start_byte()..name.end_byte()];
              return std::str::from_utf8(code).ok();
            }
          }
          _ => {}
        }
      }
      Some("<anonymous>")
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Typescript::{
      As, Async, Await, Break, Case, Catch, Const, Continue, Default, Delete, Else, Export, Extends, False, Finally, For, From, Function, FunctionExpression,
      Get, Identifier, If, Import, Import2, In, Instanceof, Let, MemberExpression, NestedIdentifier, New, Null, Number, Of, PropertyIdentifier, Return, Set,
      String, Super, Switch, This, Throw, True, Try, Typeof, Undefined, Var, Void, While, With, Yield, AMP, AMPAMP, AMPEQ, AT, BANG, BANGEQ, BANGEQEQ, CARET,
      CARETEQ, COLON, COMMA, DASH, DASHDASH, DASHEQ, DOT, EQ, EQEQ, EQEQEQ, GT, GTEQ, GTGT, GTGTEQ, GTGTGT, GTGTGTEQ, LBRACE, LBRACK, LPAREN, LT, LTEQ, LTLT,
      LTLTEQ, PERCENT, PERCENTEQ, PIPE, PIPEEQ, PIPEPIPE, PLUS, PLUSEQ, PLUSPLUS, QMARK, QMARKQMARK, SEMI, SLASH, SLASHEQ, STAR, STAREQ, STARSTAR, STARSTAREQ,
      TILDE,
    };

    match node.kind_id().into() {
      Export | Import | Import2 | Extends | DOT | From | LPAREN | COMMA | As | STAR | GTGT | GTGTGT | COLON | Return | Delete | Throw | Break | Continue
      | If | Else | Switch | Case | Default | Async | For | In | Of | While | Try | Catch | Finally | With | EQ | AT | AMPAMP | PIPEPIPE | PLUS | DASH
      | DASHDASH | PLUSPLUS | SLASH | PERCENT | STARSTAR | PIPE | AMP | LTLT | TILDE | LT | LTEQ | EQEQ | BANGEQ | GTEQ | GT | PLUSEQ | BANG | BANGEQEQ
      | EQEQEQ | DASHEQ | STAREQ | SLASHEQ | PERCENTEQ | STARSTAREQ | GTGTEQ | GTGTGTEQ | LTLTEQ | AMPEQ | CARET | CARETEQ | PIPEEQ | Yield | LBRACK
      | LBRACE | Await | QMARK | QMARKQMARK | New | Let | Var | Const | Function | FunctionExpression | SEMI => HalsteadType::Operator,
      Identifier | NestedIdentifier | MemberExpression | PropertyIdentifier | String | Number | True | False | Null | Void | This | Super | Undefined | Set
      | Get | Typeof | Instanceof => HalsteadType::Operand,
      _ => HalsteadType::Unknown,
    }
  }

  get_operator!(Typescript);
}

impl Getter for TsxCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    use Tsx::{
      ArrowFunction, Class, ClassDeclaration, FunctionDeclaration, FunctionExpression, GeneratorFunction, GeneratorFunctionDeclaration, InterfaceDeclaration,
      MethodDefinition, Program,
    };

    match node.kind_id().into() {
      FunctionExpression | MethodDefinition | GeneratorFunction | FunctionDeclaration | GeneratorFunctionDeclaration | ArrowFunction => SpaceKind::Function,
      Class | ClassDeclaration => SpaceKind::Class,
      InterfaceDeclaration => SpaceKind::Interface,
      Program => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    if let Some(name) = node.child_by_field_name("name") {
      let code = &code[name.start_byte()..name.end_byte()];
      std::str::from_utf8(code).ok()
    } else {
      // We can be in a pair: foo: function() {}
      // Or in a variable declaration: var aFun = function() {}
      if let Some(parent) = node.parent() {
        match parent.kind_id().into() {
          Mozjs::Pair => {
            if let Some(name) = parent.child_by_field_name("key") {
              let code = &code[name.start_byte()..name.end_byte()];
              return std::str::from_utf8(code).ok();
            }
          }
          Mozjs::VariableDeclarator => {
            if let Some(name) = parent.child_by_field_name("name") {
              let code = &code[name.start_byte()..name.end_byte()];
              return std::str::from_utf8(code).ok();
            }
          }
          _ => {}
        }
      }
      Some("<anonymous>")
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Tsx::{
      As, Async, Await, Break, Case, Catch, Const, Continue, Default, Delete, Else, Export, Extends, False, Finally, For, From, Function, FunctionExpression,
      Get, Identifier, If, Import, Import2, In, Instanceof, Let, MemberExpression, NestedIdentifier, New, Null, Number, Of, PropertyIdentifier, Return, Set,
      String, String2, Super, Switch, This, Throw, True, Try, Typeof, Undefined, Var, Void, While, With, Yield, AMP, AMPAMP, AMPEQ, AT, BANG, BANGEQ, BANGEQEQ,
      CARET, CARETEQ, COLON, COMMA, DASH, DASHDASH, DASHEQ, DOT, EQ, EQEQ, EQEQEQ, GT, GTEQ, GTGT, GTGTEQ, GTGTGT, GTGTGTEQ, LBRACE, LBRACK, LPAREN, LT, LTEQ,
      LTLT, LTLTEQ, PERCENT, PERCENTEQ, PIPE, PIPEEQ, PIPEPIPE, PLUS, PLUSEQ, PLUSPLUS, QMARK, QMARKQMARK, SEMI, SLASH, SLASHEQ, STAR, STAREQ, STARSTAR,
      STARSTAREQ, TILDE,
    };

    match node.kind_id().into() {
      Export | Import | Import2 | Extends | DOT | From | LPAREN | COMMA | As | STAR | GTGT | GTGTGT | COLON | Return | Delete | Throw | Break | Continue
      | If | Else | Switch | Case | Default | Async | For | In | Of | While | Try | Catch | Finally | With | EQ | AT | AMPAMP | PIPEPIPE | PLUS | DASH
      | DASHDASH | PLUSPLUS | SLASH | PERCENT | STARSTAR | PIPE | AMP | LTLT | TILDE | LT | LTEQ | EQEQ | BANGEQ | GTEQ | GT | PLUSEQ | BANG | BANGEQEQ
      | EQEQEQ | DASHEQ | STAREQ | SLASHEQ | PERCENTEQ | STARSTAREQ | GTGTEQ | GTGTGTEQ | LTLTEQ | AMPEQ | CARET | CARETEQ | PIPEEQ | Yield | LBRACK
      | LBRACE | Await | QMARK | QMARKQMARK | New | Let | Var | Const | Function | FunctionExpression | SEMI => HalsteadType::Operator,
      Identifier | NestedIdentifier | MemberExpression | PropertyIdentifier | String | String2 | Number | True | False | Null | Void | This | Super
      | Undefined | Set | Get | Typeof | Instanceof => HalsteadType::Operand,
      _ => HalsteadType::Unknown,
    }
  }

  get_operator!(Tsx);
}

impl Getter for RustCode {
  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    // we're in a function or in a class or an impl
    // for an impl: we've  'impl ... type {...'
    node.child_by_field_name("name").or_else(|| node.child_by_field_name("type")).map_or(Some("<anonymous>"), |name| {
      let code = &code[name.start_byte()..name.end_byte()];
      std::str::from_utf8(code).ok()
    })
  }

  fn get_space_kind(node: &Node) -> SpaceKind {
    use Rust::{ClosureExpression, FunctionItem, ImplItem, SourceFile, TraitItem};

    match node.kind_id().into() {
      FunctionItem | ClosureExpression => SpaceKind::Function,
      TraitItem => SpaceKind::Trait,
      ImplItem => SpaceKind::Impl,
      SourceFile => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Rust::{
      Async, Await, BinaryExpression, BooleanLiteral, CharLiteral, Continue, FloatLiteral, Fn, For, Identifier, If, InnerDocCommentMarker, IntegerLiteral, Let,
      Loop, Match, Move, MutableSpecifier, PrimitiveType, RawStringLiteral, Return, StringLiteral, Unsafe, While, Zelf, AMP, AMPAMP, AMPEQ, BANG, BANGEQ,
      CARET, CARETEQ, COMMA, DASH, DASHEQ, DASHGT, DOT, DOTDOT, DOTDOTEQ, EQ, EQEQ, EQGT, GT, GTEQ, GTGT, GTGTEQ, LBRACE, LBRACK, LPAREN, LT, LTEQ, LTLT,
      LTLTEQ, PERCENT, PERCENTEQ, PIPE, PIPEEQ, PIPEPIPE, PLUS, PLUSEQ, QMARK, SEMI, SLASH, SLASHEQ, STAR, STAREQ, UNDERSCORE,
    };

    match node.kind_id().into() {
      // `||` is treated as an operator only if it's part of a binary expression.
      // This prevents misclassification inside macros where closures without arguments (e.g., `let closure = || { /* ... */ };`)
      // are not recognized as `ClosureExpression` and their `||` node is identified as `PIPEPIPE` instead of `ClosureParameters`.
      //
      // Similarly, exclude `/` when it corresponds to the third slash in `///` (`OuterDocCommentMarker`)
      PIPEPIPE | SLASH => match node.parent() {
        Some(parent) if matches!(parent.kind_id().into(), BinaryExpression) => HalsteadType::Operator,
        _ => HalsteadType::Unknown,
      },
      // Ensure `!` is counted as an operator unless it belongs to an `InnerDocCommentMarker` `//!`
      BANG => match node.parent() {
        Some(parent) if !matches!(parent.kind_id().into(), InnerDocCommentMarker) => HalsteadType::Operator,
        _ => HalsteadType::Unknown,
      },
      LPAREN | LBRACE | LBRACK | EQGT | PLUS | STAR | Async | Await | Continue | For | If | Let | Loop | Match | Return | Unsafe | While | EQ | COMMA
      | DASHGT | QMARK | LT | GT | AMP | MutableSpecifier | DOTDOT | DOTDOTEQ | DASH | AMPAMP | PIPE | CARET | EQEQ | BANGEQ | LTEQ | GTEQ | LTLT | GTGT
      | PERCENT | PLUSEQ | DASHEQ | STAREQ | SLASHEQ | PERCENTEQ | AMPEQ | PIPEEQ | CARETEQ | LTLTEQ | GTGTEQ | Move | DOT | PrimitiveType | Fn | SEMI => {
        HalsteadType::Operator
      }
      Identifier | StringLiteral | RawStringLiteral | IntegerLiteral | FloatLiteral | BooleanLiteral | Zelf | CharLiteral | UNDERSCORE => HalsteadType::Operand,
      _ => HalsteadType::Unknown,
    }
  }

  get_operator!(Rust);
}

impl Getter for CppCode {
  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    match node.kind_id().into() {
      Cpp::FunctionDefinition | Cpp::FunctionDefinition2 | Cpp::FunctionDefinition3 => {
        if let Some(op_cast) = node.first_child(|id| Cpp::OperatorCast == id) {
          let code = &code[op_cast.start_byte()..op_cast.end_byte()];
          return std::str::from_utf8(code).ok();
        }
        // we're in a function_definition so need to get the declarator
        if let Some(declarator) = node.child_by_field_name("declarator") {
          let declarator_node = declarator;
          if let Some(fd) =
            declarator_node.first_occurrence(|id| Cpp::FunctionDeclarator == id || Cpp::FunctionDeclarator2 == id || Cpp::FunctionDeclarator3 == id)
          {
            if let Some(first) = fd.child(0) {
              match first.kind_id().into() {
                Cpp::TypeIdentifier
                | Cpp::Identifier
                | Cpp::FieldIdentifier
                | Cpp::DestructorName
                | Cpp::OperatorName
                | Cpp::QualifiedIdentifier
                | Cpp::QualifiedIdentifier2
                | Cpp::QualifiedIdentifier3
                | Cpp::QualifiedIdentifier4
                | Cpp::TemplateFunction
                | Cpp::TemplateMethod => {
                  let code = &code[first.start_byte()..first.end_byte()];
                  return std::str::from_utf8(code).ok();
                }
                _ => {}
              }
            }
          }
        }
      }
      _ => {
        if let Some(name) = node.child_by_field_name("name") {
          let code = &code[name.start_byte()..name.end_byte()];
          return std::str::from_utf8(code).ok();
        }
      }
    }
    None
  }

  fn get_space_kind(node: &Node) -> SpaceKind {
    use Cpp::{ClassSpecifier, FunctionDefinition, FunctionDefinition2, FunctionDefinition3, NamespaceDefinition, StructSpecifier, TranslationUnit};

    match node.kind_id().into() {
      FunctionDefinition | FunctionDefinition2 | FunctionDefinition3 => SpaceKind::Function,
      StructSpecifier => SpaceKind::Struct,
      ClassSpecifier => SpaceKind::Class,
      NamespaceDefinition => SpaceKind::Namespace,
      TranslationUnit => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Cpp::{
      Break, Case, Catch, Continue, Default, Delete, Do, Else, False, FieldIdentifier, For, Goto, Identifier, If, NamespaceDefinition, NamespaceIdentifier,
      New, Null, NumberLiteral, PrimitiveType, RawStringLiteral, Return, Sizeof, StringLiteral, Switch, Throw, True, Try, Try2, TypeIdentifier, TypeSpecifier,
      While, AMP, AMPAMP, AMPEQ, BANG, BANGEQ, CARET, CARETEQ, COLON, COLONCOLON, COMMA, DASH, DASHDASH, DASHGT, DOT, DOTDOTDOT, EQ, EQEQ, GT, GT2, GTEQ, GTGT,
      GTGTEQ, LBRACE, LBRACK, LPAREN, LPAREN2, LT, LTEQ, LTLT, LTLTEQ, PERCENT, PERCENTEQ, PIPE, PIPEEQ, PIPEPIPE, PLUS, PLUSEQ, PLUSPLUS, QMARK, SEMI, SLASH,
      SLASHEQ, STAR, STAREQ, TILDE,
    };

    match node.kind_id().into() {
      DOT | LPAREN | LPAREN2 | COMMA | STAR | GTGT | COLON | SEMI | Return | Break | Continue | If | Else | Switch | Case | Default | For | While | Goto
      | Do | Delete | New | Try | Try2 | Catch | Throw | EQ | AMPAMP | PIPEPIPE | DASH | DASHDASH | DASHGT | PLUS | PLUSPLUS | SLASH | PERCENT | PIPE | AMP
      | LTLT | TILDE | LT | LTEQ | EQEQ | BANGEQ | GTEQ | GT | GT2 | PLUSEQ | BANG | STAREQ | SLASHEQ | PERCENTEQ | GTGTEQ | LTLTEQ | AMPEQ | CARET
      | CARETEQ | PIPEEQ | LBRACK | LBRACE | QMARK | COLONCOLON | PrimitiveType | TypeSpecifier | Sizeof => HalsteadType::Operator,
      Identifier | TypeIdentifier | FieldIdentifier | RawStringLiteral | StringLiteral | NumberLiteral | True | False | Null | DOTDOTDOT => {
        HalsteadType::Operand
      }
      NamespaceIdentifier => match node.parent() {
        Some(parent) if matches!(parent.kind_id().into(), NamespaceDefinition) => HalsteadType::Operand,
        _ => HalsteadType::Unknown,
      },
      _ => HalsteadType::Unknown,
    }
  }

  get_operator!(Cpp);
}

// Singularity custom parsers - delegate to standard C/C++ parser for compatibility
impl Getter for PreprocCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    CppCode::get_space_kind(node)
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    CppCode::get_func_space_name(node, code)
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    CppCode::get_op_type(node)
  }

  fn get_operator_id_as_str(id: u16) -> &'static str {
    CppCode::get_operator_id_as_str(id)
  }
}

impl Getter for CcommentCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    CppCode::get_space_kind(node)
  }

  fn get_func_space_name<'a>(node: &Node, code: &'a [u8]) -> Option<&'a str> {
    CppCode::get_func_space_name(node, code)
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    CppCode::get_op_type(node)
  }

  fn get_operator_id_as_str(id: u16) -> &'static str {
    CppCode::get_operator_id_as_str(id)
  }
}

impl Getter for JavaCode {
  fn get_space_kind(node: &Node) -> SpaceKind {
    use Java::{ClassDeclaration, ConstructorDeclaration, InterfaceDeclaration, LambdaExpression, MethodDeclaration, Program};

    match node.kind_id().into() {
      ClassDeclaration => SpaceKind::Class,
      MethodDeclaration | ConstructorDeclaration | LambdaExpression => SpaceKind::Function,
      InterfaceDeclaration => SpaceKind::Interface,
      Program => SpaceKind::Unit,
      _ => SpaceKind::Unknown,
    }
  }

  fn get_op_type(node: &Node) -> HalsteadType {
    use Java::{
      Abstract, Assert, BinaryIntegerLiteral, Break, Case, Catch, CharacterLiteral, ClassLiteral, Continue, DecimalFloatingPointLiteral, DecimalIntegerLiteral,
      Default, Do, Else, Extends, Final, Finally, Float, For, HexFloatingPointLiteral, HexIntegerLiteral, Identifier, If, Implements, Instanceof, Int, New,
      NullLiteral, OctalIntegerLiteral, Return, StringLiteral, Super, Switch, Synchronized, This, Throw, Throws, Throws2, Transient, Try, VoidType, While, AMP,
      AMPAMP, AMPEQ, BANG, BANGEQ, CARET, CARETEQ, COLON, COLONCOLON, COMMA, DASH, DASHDASH, DASHEQ, EQ, EQEQ, GT, GTEQ, GTGT, GTGTEQ, GTGTGT, GTGTGTEQ,
      LBRACE, LBRACK, LPAREN, LT, LTEQ, LTLT, LTLTEQ, PERCENT, PERCENTEQ, PIPE, PIPEEQ, PIPEPIPE, PLUS, PLUSEQ, PLUSPLUS, QMARK, SEMI, SLASH, SLASHEQ, STAR,
      STAREQ, TILDE,
    };
    // Some guides that informed grammar choice for Halstead
    // keywords, operators, literals: https://docs.oracle.com/javase/specs/jls/se18/html/jls-3.html#jls-3.12
    // https://www.geeksforgeeks.org/software-engineering-halsteads-software-metrics/?msclkid=5e181114abef11ecbb03527e95a34828
    match node.kind_id().into() {
            // Operator: control flow
            | If | Else | Switch | Case | Try | Catch | Throw | Throws | Throws2 | For | While | Continue | Break | Do | Finally
            // Operator: keywords
            | New | Return | Default | Abstract | Assert | Instanceof | Extends | Final | Implements | Transient | Synchronized | Super | This | VoidType
            // Operator: brackets and comma and terminators (separators)
            | SEMI | COMMA | COLONCOLON | LBRACE | LBRACK | LPAREN // | RBRACE | RBRACK | RPAREN | DOTDOTDOT | DOT
            // Operator: operators
            | EQ | LT | GT | BANG | TILDE | QMARK | COLON // no grammar for lambda operator ->
            | EQEQ | LTEQ | GTEQ | BANGEQ | AMPAMP | PIPEPIPE | PLUSPLUS | DASHDASH
            | PLUS | DASH | STAR | SLASH | AMP | PIPE | CARET | PERCENT| LTLT | GTGT | GTGTGT
            | PLUSEQ | DASHEQ | STAREQ | SLASHEQ | AMPEQ | PIPEEQ | CARETEQ | PERCENTEQ | LTLTEQ | GTGTEQ | GTGTGTEQ
            // primitive types
            | Int | Float
            => {
                HalsteadType::Operator
            },
            // Operands: variables, constants, literals
            Identifier | NullLiteral | ClassLiteral | StringLiteral | CharacterLiteral | HexIntegerLiteral | OctalIntegerLiteral | BinaryIntegerLiteral | DecimalIntegerLiteral | HexFloatingPointLiteral | DecimalFloatingPointLiteral  => {
                HalsteadType::Operand
            },
            _ => {
                HalsteadType::Unknown
            },
        }
  }

  fn get_operator_id_as_str(id: u16) -> &'static str {
    let typ = id.into();
    match typ {
      Java::LPAREN => "()",
      Java::LBRACK => "[]",
      Java::LBRACE => "{}",
      Java::VoidType => "void",
      _ => typ.into(),
    }
  }
}

impl Getter for KotlinCode {}

// BEAM languages - Elixir, Erlang, Gleam (minimal implementations)
impl Getter for ElixirCode {}
impl Getter for ErlangCode {}
impl Getter for GleamCode {}

// Lua (minimal implementation)
impl Getter for LuaCode {}
