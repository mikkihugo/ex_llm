import re

# Language syntax patterns based on complexity_calculator.rs
patterns = {
    "c": {
        "function_definitions": ["void ", "int ", "char ", "float "],
        "control_flow": ["if ", "else ", "for ", "while ", "switch "],
        "operators": ["&&", "||", "!", "==", "!="],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["if", "assert"]
    },
    "cpp": {
        "function_definitions": ["void ", "int ", "bool ", "string "],
        "control_flow": ["if ", "else ", "for ", "while ", "switch ", "try "],
        "operators": ["&&", "||", "!", "==", "!="],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["try", "catch", "throw"]
    },
    "javascript": {
        "function_definitions": ["function ", "=> ", "async function "],
        "control_flow": ["if ", "else ", "for ", "while ", "switch ", "try "],
        "operators": ["&&", "||", "!", "===", "!=="],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["try", "catch", "throw"]
    },
    "typescript": {
        "function_definitions": ["function ", "=> ", "async function "],
        "control_flow": ["if ", "else ", "for ", "while ", "switch ", "try "],
        "operators": ["&&", "||", "!", "===", "!=="],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["try", "catch", "throw"]
    },
    "python": {
        "function_definitions": ["def ", "async def "],
        "control_flow": ["if ", "elif ", "else ", "for ", "while ", "try "],
        "operators": ["and", "or", "not", "in", "is"],
        "opening_delimiters": [":"],
        "closing_delimiters": [""],
        "comments": ["#"],
        "error_handling": ["try", "except", "finally"]
    },
    "java": {
        "function_definitions": ["public ", "private ", "protected "],
        "control_flow": ["if ", "else ", "for ", "while ", "switch ", "try "],
        "operators": ["&&", "||", "!", "==", "!="],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["try", "catch", "throw"]
    },
    "csharp": {
        "function_definitions": ["void ", "public ", "private ", "async "],
        "control_flow": ["if ", "else ", "for ", "while ", "switch ", "try "],
        "operators": ["&&", "||", "!", "==", "!=", "??"],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["try", "catch", "throw"]
    },
    "go": {
        "function_definitions": ["func "],
        "control_flow": ["if ", "else ", "for ", "switch "],
        "operators": ["&&", "||", "!", "==", "!="],
        "opening_delimiters": ["{"],
        "closing_delimiters": ["}"],
        "comments": ["//", "/*"],
        "error_handling": ["if", "err", "panic"]
    },
    "lua": {
        "function_definitions": ["function "],
        "control_flow": ["if ", "elseif ", "for ", "while "],
        "operators": ["and", "or", "not"],
        "opening_delimiters": ["do"],
        "closing_delimiters": ["end"],
        "comments": ["--"],
        "error_handling": ["pcall", "xpcall"]
    },
    "ruby": {
        "function_definitions": ["def "],
        "control_flow": ["if ", "elsif ", "else ", "for ", "while ", "begin "],
        "operators": ["&&", "||", "!", "==", "!="],
        "opening_delimiters": ["do", "{"],
        "closing_delimiters": ["end", "}"],
        "comments": ["#"],
        "error_handling": ["begin", "rescue", "ensure"]
    }
}

# Languages that don't need complex syntax patterns (data/config formats)
simple_langs = ["bash", "json", "yaml", "toml", "markdown", "dockerfile", "sql"]

for lang in simple_langs:
    patterns[lang] = {
        "function_definitions": [],
        "control_flow": [],
        "operators": [],
        "opening_delimiters": [],
        "closing_delimiters": [],
        "comments": [],
        "error_handling": []
    }

print("Syntax patterns defined for all languages")
