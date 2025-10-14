// Gleam language support - based on tree-sitter-gleam 1.0.0
// Node types extracted from actual tree-sitter grammar

use num_derive::FromPrimitive;

#[derive(Clone, Debug, PartialEq, Eq, FromPrimitive)]
pub enum Gleam {
    End = 0,

    // Comments
    ModuleComment = 1,
    StatementComment = 2,
    Comment = 3,

    // Modifiers
    VisibilityModifier = 63,  // pub
    OpacityModifier = 64,      // opaque

    // Literals
    Float = 69,
    QuotedContent = 95,
    Integer = 220,

    // File structure
    SourceFile = 96,

    // Imports and modules
    Import = 103,
    Module = 104,
    UnqualifiedImports = 105,
    UnqualifiedImport = 106,

    // Constants and attributes
    Constant = 107,
    Attribute = 100,
    AttributeValue = 102,

    // Collections
    Tuple = 109,
    List = 110,
    BitString = 111,
    BitStringSegment = 112,
    BitStringSegmentOptions = 113,
    BitStringSegmentOption = 116,

    // Records
    Record = 117,
    Arguments = 118,
    Argument = 119,
    FieldAccess = 120,

    // Type system
    TupleType = 123,
    FunctionType = 124,
    FunctionParameterTypes = 125,
    Type = 126,
    TypeArguments = 127,
    TypeArgument = 128,
    TypeIdentifier = 238,
    TypeDefinition = 212,
    DataConstructors = 213,
    DataConstructor = 214,
    TypeAlias = 217,

    // External functions
    ExternalType = 129,
    ExternalFunction = 130,
    ExternalFunctionBody = 133,

    // Functions
    Function = 134,
    FunctionParameters = 135,
    FunctionParameter = 136,
    FunctionBody = 274,
    AnonymousFunction = 159,

    // Expressions
    BinaryExpression = 144,
    Todo = 147,
    Panic = 148,
    PipelineEcho = 149,
    Echo = 150,
    TupleAccess = 173,
    BooleanNegation = 180,
    IntegerNegation = 181,
    Hole = 193,
    FunctionCall = 194,

    // Control flow
    Block = 162,
    Case = 163,
    CaseSubjects = 164,
    CaseClauses = 165,
    CaseClause = 166,
    CaseClausePatterns = 167,
    CaseClausePattern = 168,
    CaseClauseGuard = 169,

    // Let bindings
    Let = 175,
    LetAssert = 174,
    Assert = 179,
    Use = 176,
    UseAssignments = 177,
    UseAssignment = 178,

    // Record operations
    RecordUpdate = 183,
    RecordUpdateArguments = 184,
    RecordUpdateArgument = 185,

    // Patterns
    RecordPattern = 198,
    RecordPatternArguments = 199,
    RecordPatternArgument = 200,
    PatternSpread = 201,
    TuplePattern = 202,
    BitStringPattern = 203,
    ListPattern = 210,
    ListPatternTail = 211,

    // Strings
    String = 218,
    EscapeSequence = 219,

    // Special values
    Identifier = 235,
    Discard = 237,  // underscore _
}

impl From<u16> for Gleam {
    fn from(value: u16) -> Self {
        num::FromPrimitive::from_u16(value).unwrap_or(Gleam::End)
    }
}

impl PartialEq<u16> for Gleam {
  #[inline(always)]
  fn eq(&self, x: &u16) -> bool {
    *self == Into::<Self>::into(*x)
  }
}

impl PartialEq<Gleam> for u16 {
  #[inline(always)]
  fn eq(&self, x: &Gleam) -> bool {
    *x == *self
  }
}
