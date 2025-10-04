%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: ["test/support/"]
      },
      strict: false,
      checks: [
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []}
      ]
    }
  ]
}
