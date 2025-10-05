{application, test_project, [
    {vsn, "1.0.0"},
    {applications, [gleam_stdlib,
                    gleeunit]},
    {description, ""},
    {modules, [test_project,
               test_project@@main,
               test_project_test]},
    {registered, []}
]}.
