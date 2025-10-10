    pub fn validate_function_name(&self, name: &str) -> bool {
        // Default: snake_case functions
        self.validate_snake_case(name)
    }
    pub fn validate_function_name_for_language(&self, name: &str, language: &str) -> bool {
        match language.to_lowercase().as_str() {
            "elixir" | "ex" | "exs" => self.validate_snake_case(name),
            "rust" | "rs" => self.validate_snake_case(name),
            "typescript" | "ts" | "tsx" => self.validate_camel_case(name),
            "javascript" | "js" | "jsx" => self.validate_camel_case(name),
            "gleam" => self.validate_snake_case(name),
            "go" | "golang" => self.validate_camel_case(name),
            "python" | "py" => self.validate_snake_case(name),
            _ => self.validate_snake_case(name),
        }
    }
    fn to_snake_case(&self, input: &str) -> String {
        self.convert_to_snake_case(input)
    }
    fn to_kebab_case(&self, input: &str) -> String {
        self.convert_to_kebab_case(input)
    }
