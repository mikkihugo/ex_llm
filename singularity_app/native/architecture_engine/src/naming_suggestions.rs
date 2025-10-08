    pub fn suggest_function_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Function, context)
    }
    pub fn suggest_module_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Module, context)
    }
    pub fn suggest_variable_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Variable, context)
    }
    pub fn suggest_class_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Class, context)
    }
    pub fn suggest_filename(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::File, context)
    }
    pub fn suggest_directory_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Directory, context)
    }
