-module(test_project).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/test_project.gleam").
-export([main/0]).

-file("src/test_project.gleam", 3).
-spec main() -> nil.
main() ->
    gleam_stdlib:println(<<"Hello from test_project!"/utf8>>).
