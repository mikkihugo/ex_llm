// Elixir language support - based on tree-sitter-elixir 0.3.4
// Node types extracted from actual tree-sitter grammar

use num_derive::FromPrimitive;

#[derive(Clone, Debug, PartialEq, Eq, FromPrimitive)]
pub enum Elixir {
    End = 0,

    // Literals
    Alias = 7,
    Integer = 8,
    Float = 9,
    Char = 10,
    Atom = 14,
    Comment = 97,
    QuotedContent = 98,

    // Structure
    Source = 124,
    Block = 127,
    Identifier = 128,
    Boolean = 129,
    Nil = 130,
    QuotedAtom = 132,

    // String types
    String = 153,
    Charlist = 154,
    Interpolation = 155,
    Sigil = 156,

    // Collections
    Keywords = 157,
    Pair = 159,
    QuotedKeyword = 161,
    List = 162,
    Tuple = 163,
    Bitstring = 164,
    Map = 165,
    Struct = 166,

    // Operators
    UnaryOperator = 169,
    BinaryOperator = 171,
    OperatorIdentifier = 172,
    Dot = 173,

    // Function calls and definitions
    Call = 174,
    Arguments = 186,
    DoBlock = 190,
    AfterBlock = 191,
    RescueBlock = 192,
    CatchBlock = 193,
    ElseBlock = 194,
    AccessCall = 195,

    // Control flow
    StabClause = 196,
    Body = 202,
    AnonymousFunction = 203,

    // Map content
    MapContent = 234,
}

impl From<u16> for Elixir {
    fn from(value: u16) -> Self {
        num::FromPrimitive::from_u16(value).unwrap_or(Elixir::End)
    }
}

impl PartialEq<u16> for Elixir {
  #[inline(always)]
  fn eq(&self, x: &u16) -> bool {
    *self == Into::<Self>::into(*x)
  }
}

impl PartialEq<Elixir> for u16 {
  #[inline(always)]
  fn eq(&self, x: &Elixir) -> bool {
    *x == *self
  }
}
