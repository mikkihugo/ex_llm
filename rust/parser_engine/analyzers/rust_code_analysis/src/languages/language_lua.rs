// Lua language support - based on tree-sitter-lua 0.2.0
// Minimal enum for RCA metrics support

use num_derive::FromPrimitive;

#[derive(Clone, Debug, PartialEq, Eq, FromPrimitive)]
pub enum Lua {
    End = 0,

    // Comments
    Comment = 1,

    // Basic structure
    Program = 2,

    // Functions
    FunctionDeclaration = 3,
    FunctionDefinition = 4,
    Function = 5,

    // Control flow
    IfStatement = 10,
    WhileStatement = 11,
    RepeatStatement = 12,
    ForStatement = 13,

    // Variables and assignments
    Assignment = 20,
    LocalVariable = 21,
    Variable = 22,

    // Operators
    BinaryExpression = 30,
    UnaryExpression = 31,

    // Literals
    String = 40,
    Number = 41,
    True = 42,
    False = 43,
    Nil = 44,

    // Tables
    TableConstructor = 50,
    Field = 51,

    // Calls and identifiers
    FunctionCall = 60,
    Identifier = 61,

    // Return
    ReturnStatement = 70,
}

impl From<u16> for Lua {
    fn from(value: u16) -> Self {
        num::FromPrimitive::from_u16(value).unwrap_or(Lua::End)
    }
}

impl PartialEq<u16> for Lua {
  #[inline(always)]
  fn eq(&self, x: &u16) -> bool {
    *self == Into::<Self>::into(*x)
  }
}

impl PartialEq<Lua> for u16 {
  #[inline(always)]
  fn eq(&self, x: &Lua) -> bool {
    *x == *self
  }
}
