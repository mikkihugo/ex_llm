use tree_sitter::{Language, Parser, Query, QueryCursor};

/// Dockerfile parser using tree-sitter-dockerfile
pub struct DockerfileParser {
    language: Language,
    parser: Parser,
    query: Query,
}

impl DockerfileParser {
    /// Create a new Dockerfile parser
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let language = tree_sitter_dockerfile::language();
        let mut parser = Parser::new();
        parser.set_language(language)?;
        
        // Query for common Dockerfile elements
        let query = Query::new(
            language,
            r#"
            (from_statement) @from
            (run_statement) @run
            (copy_statement) @copy
            (add_statement) @add
            (cmd_statement) @cmd
            (entrypoint_statement) @entrypoint
            (env_statement) @env
            (expose_statement) @expose
            (volume_statement) @volume
            (workdir_statement) @workdir
            (user_statement) @user
            (arg_statement) @arg
            (label_statement) @label
            (onbuild_statement) @onbuild
            (stopsignal_statement) @stopsignal
            (healthcheck_statement) @healthcheck
            (shell_statement) @shell
            (comment) @comment
            (string) @string
            "#
        )?;

        Ok(Self {
            language,
            parser,
            query,
        })
    }

    /// Parse Dockerfile content and extract structured information
    pub fn parse(&mut self, content: &str) -> Result<DockerfileDocument, Box<dyn std::error::Error>> {
        let tree = self.parser.parse(content, None)
            .ok_or("Failed to parse Dockerfile")?;
        
        let mut cursor = QueryCursor::new();
        let captures = cursor.captures(&self.query, tree.root_node(), content.as_bytes());
        
        let mut document = DockerfileDocument::new();
        
        for (matched_node, _) in captures {
            for capture in matched_node.captures {
                let node = capture.node;
                let text = &content[node.byte_range()];
                let start = node.start_position();
                let end = node.end_position();
                
                // Map capture index to capture name based on query order
                let capture_name = match capture.index {
                    0 => "from",
                    1 => "run",
                    2 => "copy",
                    3 => "add",
                    4 => "cmd",
                    5 => "entrypoint",
                    6 => "env",
                    7 => "expose",
                    8 => "volume",
                    9 => "workdir",
                    10 => "user",
                    11 => "arg",
                    12 => "label",
                    13 => "onbuild",
                    14 => "stopsignal",
                    15 => "healthcheck",
                    16 => "shell",
                    17 => "comment",
                    18 => "string",
                    _ => "unknown",
                };
                
                match capture_name {
                    "from" => {
                        let from_info = self.extract_from_info(node, content);
                        document.add_from(from_info);
                    }
                    "run" => {
                        let run_info = self.extract_run_info(node, content);
                        document.add_run(run_info);
                    }
                    "copy" => {
                        let copy_info = self.extract_copy_info(node, content);
                        document.add_copy(copy_info);
                    }
                    "add" => {
                        let add_info = self.extract_add_info(node, content);
                        document.add_add(add_info);
                    }
                    "cmd" => {
                        let cmd_info = self.extract_cmd_info(node, content);
                        document.add_cmd(cmd_info);
                    }
                    "entrypoint" => {
                        let entrypoint_info = self.extract_entrypoint_info(node, content);
                        document.add_entrypoint(entrypoint_info);
                    }
                    "env" => {
                        let env_info = self.extract_env_info(node, content);
                        document.add_env(env_info);
                    }
                    "expose" => {
                        let expose_info = self.extract_expose_info(node, content);
                        document.add_expose(expose_info);
                    }
                    "volume" => {
                        let volume_info = self.extract_volume_info(node, content);
                        document.add_volume(volume_info);
                    }
                    "workdir" => {
                        let workdir_info = self.extract_workdir_info(node, content);
                        document.add_workdir(workdir_info);
                    }
                    "user" => {
                        let user_info = self.extract_user_info(node, content);
                        document.add_user(user_info);
                    }
                    "arg" => {
                        let arg_info = self.extract_arg_info(node, content);
                        document.add_arg(arg_info);
                    }
                    "label" => {
                        let label_info = self.extract_label_info(node, content);
                        document.add_label(label_info);
                    }
                    "onbuild" => {
                        let onbuild_info = self.extract_onbuild_info(node, content);
                        document.add_onbuild(onbuild_info);
                    }
                    "stopsignal" => {
                        let stopsignal_info = self.extract_stopsignal_info(node, content);
                        document.add_stopsignal(stopsignal_info);
                    }
                    "healthcheck" => {
                        let healthcheck_info = self.extract_healthcheck_info(node, content);
                        document.add_healthcheck(healthcheck_info);
                    }
                    "shell" => {
                        let shell_info = self.extract_shell_info(node, content);
                        document.add_shell(shell_info);
                    }
                    "comment" => {
                        let comment_info = self.extract_comment_info(node, content);
                        document.add_comment(comment_info);
                    }
                    "string" => {
                        let string_info = self.extract_string_info(node, content);
                        document.add_string(string_info);
                    }
                    _ => {}
                }
            }
        }
        
        Ok(document)
    }

    fn extract_from_info(&self, node: tree_sitter::Node, content: &str) -> FromInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        // Extract base image from FROM statement
        let base_image = self.extract_base_image(text);
        
        FromInfo {
            base_image,
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_run_info(&self, node: tree_sitter::Node, content: &str) -> RunInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        RunInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_copy_info(&self, node: tree_sitter::Node, content: &str) -> CopyInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CopyInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_add_info(&self, node: tree_sitter::Node, content: &str) -> AddInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        AddInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_cmd_info(&self, node: tree_sitter::Node, content: &str) -> CmdInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CmdInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_entrypoint_info(&self, node: tree_sitter::Node, content: &str) -> EntrypointInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        EntrypointInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_env_info(&self, node: tree_sitter::Node, content: &str) -> EnvInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        EnvInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_expose_info(&self, node: tree_sitter::Node, content: &str) -> ExposeInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        ExposeInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_volume_info(&self, node: tree_sitter::Node, content: &str) -> VolumeInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        VolumeInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_workdir_info(&self, node: tree_sitter::Node, content: &str) -> WorkdirInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        WorkdirInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_user_info(&self, node: tree_sitter::Node, content: &str) -> UserInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        UserInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_arg_info(&self, node: tree_sitter::Node, content: &str) -> ArgInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        ArgInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_label_info(&self, node: tree_sitter::Node, content: &str) -> LabelInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        LabelInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_onbuild_info(&self, node: tree_sitter::Node, content: &str) -> OnbuildInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        OnbuildInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_stopsignal_info(&self, node: tree_sitter::Node, content: &str) -> StopsignalInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        StopsignalInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_healthcheck_info(&self, node: tree_sitter::Node, content: &str) -> HealthcheckInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        HealthcheckInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_shell_info(&self, node: tree_sitter::Node, content: &str) -> ShellInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        ShellInfo {
            line: start.row,
            content: text.to_string(),
        }
    }

    fn extract_comment_info(&self, node: tree_sitter::Node, content: &str) -> CommentInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        CommentInfo {
            content: text.to_string(),
            line: start.row,
        }
    }

    fn extract_string_info(&self, node: tree_sitter::Node, content: &str) -> StringInfo {
        let text = &content[node.byte_range()];
        let start = node.start_position();
        
        StringInfo {
            value: text.to_string(),
            line: start.row,
        }
    }

    fn extract_base_image(&self, text: &str) -> String {
        // Extract base image from FROM statement
        if let Some(from_pos) = text.find("FROM") {
            let after_from = &text[from_pos + 4..];
            let parts: Vec<&str> = after_from.split_whitespace().collect();
            if let Some(image) = parts.first() {
                return image.to_string();
            }
        }
        String::new()
    }
}

/// Structured representation of a Dockerfile document
#[derive(Debug, Clone)]
pub struct DockerfileDocument {
    pub froms: Vec<FromInfo>,
    pub runs: Vec<RunInfo>,
    pub copies: Vec<CopyInfo>,
    pub adds: Vec<AddInfo>,
    pub cmds: Vec<CmdInfo>,
    pub entrypoints: Vec<EntrypointInfo>,
    pub envs: Vec<EnvInfo>,
    pub exposes: Vec<ExposeInfo>,
    pub volumes: Vec<VolumeInfo>,
    pub workdirs: Vec<WorkdirInfo>,
    pub users: Vec<UserInfo>,
    pub args: Vec<ArgInfo>,
    pub labels: Vec<LabelInfo>,
    pub onbuilds: Vec<OnbuildInfo>,
    pub stopsignals: Vec<StopsignalInfo>,
    pub healthchecks: Vec<HealthcheckInfo>,
    pub shells: Vec<ShellInfo>,
    pub comments: Vec<CommentInfo>,
    pub strings: Vec<StringInfo>,
}

impl DockerfileDocument {
    pub fn new() -> Self {
        Self {
            froms: Vec::new(),
            runs: Vec::new(),
            copies: Vec::new(),
            adds: Vec::new(),
            cmds: Vec::new(),
            entrypoints: Vec::new(),
            envs: Vec::new(),
            exposes: Vec::new(),
            volumes: Vec::new(),
            workdirs: Vec::new(),
            users: Vec::new(),
            args: Vec::new(),
            labels: Vec::new(),
            onbuilds: Vec::new(),
            stopsignals: Vec::new(),
            healthchecks: Vec::new(),
            shells: Vec::new(),
            comments: Vec::new(),
            strings: Vec::new(),
        }
    }

    pub fn add_from(&mut self, from: FromInfo) {
        self.froms.push(from);
    }

    pub fn add_run(&mut self, run: RunInfo) {
        self.runs.push(run);
    }

    pub fn add_copy(&mut self, copy: CopyInfo) {
        self.copies.push(copy);
    }

    pub fn add_add(&mut self, add: AddInfo) {
        self.adds.push(add);
    }

    pub fn add_cmd(&mut self, cmd: CmdInfo) {
        self.cmds.push(cmd);
    }

    pub fn add_entrypoint(&mut self, entrypoint: EntrypointInfo) {
        self.entrypoints.push(entrypoint);
    }

    pub fn add_env(&mut self, env: EnvInfo) {
        self.envs.push(env);
    }

    pub fn add_expose(&mut self, expose: ExposeInfo) {
        self.exposes.push(expose);
    }

    pub fn add_volume(&mut self, volume: VolumeInfo) {
        self.volumes.push(volume);
    }

    pub fn add_workdir(&mut self, workdir: WorkdirInfo) {
        self.workdirs.push(workdir);
    }

    pub fn add_user(&mut self, user: UserInfo) {
        self.users.push(user);
    }

    pub fn add_arg(&mut self, arg: ArgInfo) {
        self.args.push(arg);
    }

    pub fn add_label(&mut self, label: LabelInfo) {
        self.labels.push(label);
    }

    pub fn add_onbuild(&mut self, onbuild: OnbuildInfo) {
        self.onbuilds.push(onbuild);
    }

    pub fn add_stopsignal(&mut self, stopsignal: StopsignalInfo) {
        self.stopsignals.push(stopsignal);
    }

    pub fn add_healthcheck(&mut self, healthcheck: HealthcheckInfo) {
        self.healthchecks.push(healthcheck);
    }

    pub fn add_shell(&mut self, shell: ShellInfo) {
        self.shells.push(shell);
    }

    pub fn add_comment(&mut self, comment: CommentInfo) {
        self.comments.push(comment);
    }

    pub fn add_string(&mut self, string: StringInfo) {
        self.strings.push(string);
    }

    /// Get base images used
    pub fn get_base_images(&self) -> Vec<String> {
        self.froms.iter()
            .map(|f| f.base_image.clone())
            .filter(|img| !img.is_empty())
            .collect()
    }

    /// Get exposed ports
    pub fn get_exposed_ports(&self) -> Vec<String> {
        self.exposes.iter()
            .map(|e| e.content.clone())
            .collect()
    }

    /// Get environment variables
    pub fn get_environment_variables(&self) -> Vec<String> {
        self.envs.iter()
            .map(|e| e.content.clone())
            .collect()
    }

    /// Get build arguments
    pub fn get_build_arguments(&self) -> Vec<String> {
        self.args.iter()
            .map(|a| a.content.clone())
            .collect()
    }

    /// Get complexity score
    pub fn get_complexity_score(&self) -> u32 {
        let mut score = 0;
        
        score += self.runs.len() as u32;
        score += self.copies.len() as u32;
        score += self.adds.len() as u32;
        score += self.envs.len() as u32;
        score += self.volumes.len() as u32;
        score += self.workdirs.len() as u32;
        score += self.labels.len() as u32;
        
        score
    }
}

#[derive(Debug, Clone)]
pub struct FromInfo {
    pub base_image: String,
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct RunInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct CopyInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct AddInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct CmdInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct EntrypointInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct EnvInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ExposeInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct VolumeInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct WorkdirInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct UserInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ArgInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct LabelInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct OnbuildInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct StopsignalInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct HealthcheckInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ShellInfo {
    pub line: usize,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct CommentInfo {
    pub content: String,
    pub line: usize,
}

#[derive(Debug, Clone)]
pub struct StringInfo {
    pub value: String,
    pub line: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_dockerfile() {
        let dockerfile = r#"
# Simple Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
"#;

        let mut parser = DockerfileParser::new().unwrap();
        let doc = parser.parse(dockerfile).unwrap();

        assert_eq!(doc.froms.len(), 1);
        assert_eq!(doc.workdirs.len(), 1);
        assert_eq!(doc.copies.len(), 2);
        assert_eq!(doc.runs.len(), 1);
        assert_eq!(doc.exposes.len(), 1);
        assert_eq!(doc.cmds.len(), 1);
        assert_eq!(doc.comments.len(), 1);
    }
}