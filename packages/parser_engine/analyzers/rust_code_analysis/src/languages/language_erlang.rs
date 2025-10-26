// Erlang language support - based on tree-sitter-erlang 0.15.0
// Node types extracted from actual tree-sitter grammar

use num_derive::FromPrimitive;

#[derive(Clone, Debug, PartialEq, Eq, FromPrimitive)]
pub enum Erlang {
    End = 0,

    // Literals
    Atom = 1,
    Var = 130,
    Integer = 131,
    Float = 132,
    Char = 136,
    Comment = 137,

    // File structure
    SourceFile = 141,

    // Attributes
    ModuleAttribute = 158,
    BehaviourAttribute = 159,
    ExportAttribute = 160,
    ImportAttribute = 161,
    OptionalCallbacksAttribute = 162,
    FA = 163,  // Function/Arity pair
    ExportTypeAttribute = 164,

    // Type system
    TypeAlias = 178,
    RecordDecl = 183,
    Spec = 184,
    Callback = 185,
    TypeName = 182,
    TypeSig = 193,
    AnnType = 195,
    FunType = 198,
    RangeType = 199,

    // Functions
    FunDecl = 191,
    FunctionClause = 202,
    ClauseBody = 204,
    Call = 254,
    InternalFun = 263,
    ExternalFun = 264,
    AnonymousFun = 265,
    Arity = 268,
    FunClause = 270,

    // Expressions
    CatchExpr = 206,
    MatchExpr = 207,
    CondMatchExpr = 208,
    BinaryOpExpr = 209,
    UnaryOpExpr = 210,
    Remote = 212,
    ParenExpr = 214,
    BlockExpr = 215,

    // Collections
    List = 216,
    Binary = 217,
    BinElement = 218,
    Tuple = 237,
    MapExpr = 239,
    MapField = 241,

    // Records
    RecordExpr = 246,
    RecordName = 247,
    RecordField = 251,
    RecordFieldExpr = 244,
    RecordUpdateExpr = 245,

    // Control flow
    IfExpr = 255,
    IfClause = 256,
    CaseExpr = 257,
    CrClause = 260,  // Case/Receive clause
    ReceiveExpr = 261,
    ReceiveAfter = 262,
    TryExpr = 271,
    TryAfter = 273,
    CatchClause = 274,

    // Comprehensions
    ListComprehension = 226,
    BinaryComprehension = 227,
    MapComprehension = 228,
    Generator = 232,
    BGenerator = 233,

    // Guard
    Guard = 298,
    GuardClause = 299,

    // Arguments
    ExprArgs = 296,
    VarArgs = 297,
}

impl From<u16> for Erlang {
    fn from(value: u16) -> Self {
        num::FromPrimitive::from_u16(value).unwrap_or(Erlang::End)
    }
}

impl PartialEq<u16> for Erlang {
  #[inline(always)]
  fn eq(&self, x: &u16) -> bool {
    *self == Into::<Self>::into(*x)
  }
}

impl PartialEq<Erlang> for u16 {
  #[inline(always)]
  fn eq(&self, x: &Erlang) -> bool {
    *x == *self
  }
}
