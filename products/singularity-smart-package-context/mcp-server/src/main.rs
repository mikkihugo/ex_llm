use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use singularity_smart_package_context_backend::{
    Ecosystem, FileType, SmartPackageContext,
};
use std::io::{self, BufRead, Write};
use tracing::info;

/// MCP tool call request
#[derive(Debug, Serialize, Deserialize)]
struct ToolCall {
    name: String,
    arguments: Value,
}

/// MCP tool result response
#[derive(Debug, Serialize, Deserialize)]
struct ToolResult {
    success: bool,
    result: Value,
    error: Option<String>,
}

/// Initialize the MCP server and handle tool calls from Claude
#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging (writes to stderr so it doesn't interfere with MCP protocol)
    tracing_subscriber::fmt()
        .with_writer(io::stderr)
        .init();

    info!("Starting Singularity Smart Package Context MCP Server");

    // Create the backend context
    let ctx = match SmartPackageContext::new().await {
        Ok(ctx) => ctx,
        Err(e) => {
            eprintln!("Failed to create SmartPackageContext: {}", e);
            return Err(e.into());
        }
    };

    // Health check
    match ctx.health_check().await {
        Ok(health) => {
            info!("Health check passed: {}", health.message);
            println!("{{\"status\":\"ready\",\"message\":\"{}\"}}", health.message);
        }
        Err(e) => {
            eprintln!("Health check failed: {}", e);
            return Err(e.into());
        }
    }

    // Main event loop: read from stdin, process tool calls, write to stdout
    let stdin = io::stdin();
    let handle = stdin.lock();
    let reader = io::BufReader::new(handle);

    for line in reader.lines() {
        let line = line?;
        if line.is_empty() {
            continue;
        }

        // Parse the tool call
        let tool_call: ToolCall = match serde_json::from_str(&line) {
            Ok(call) => call,
            Err(e) => {
                let error = ToolResult {
                    success: false,
                    result: Value::Null,
                    error: Some(format!("Invalid JSON: {}", e)),
                };
                println!("{}", serde_json::to_string(&error)?);
                continue;
            }
        };

        // Process the tool call
        let result = process_tool_call(&ctx, &tool_call).await;

        // Send response
        println!("{}", serde_json::to_string(&result)?);
        io::stdout().flush()?;
    }

    Ok(())
}

/// Process a single tool call
async fn process_tool_call(
    ctx: &SmartPackageContext,
    call: &ToolCall,
) -> ToolResult {
    match call.name.as_str() {
        "get_package_info" => handle_get_package_info(ctx, &call.arguments).await,
        "get_package_examples" => handle_get_package_examples(ctx, &call.arguments).await,
        "get_package_patterns" => handle_get_package_patterns(ctx, &call.arguments).await,
        "search_patterns" => handle_search_patterns(ctx, &call.arguments).await,
        "analyze_file" => handle_analyze_file(ctx, &call.arguments).await,
        _ => ToolResult {
            success: false,
            result: Value::Null,
            error: Some(format!("Unknown tool: {}", call.name)),
        },
    }
}

/// Handle get_package_info tool call
///
/// Arguments:
/// - name: string (required) - Package name
/// - ecosystem: string (optional, default: "npm") - Ecosystem (npm, cargo, hex, pypi, etc.)
async fn handle_get_package_info(
    ctx: &SmartPackageContext,
    args: &Value,
) -> ToolResult {
    let name = match args.get("name").and_then(|v| v.as_str()) {
        Some(n) => n,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some("Missing required argument: name".to_string()),
            }
        }
    };

    let ecosystem_str = args
        .get("ecosystem")
        .and_then(|v| v.as_str())
        .unwrap_or("npm");

    let ecosystem = match Ecosystem::from_str(ecosystem_str) {
        Some(e) => e,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some(format!("Invalid ecosystem: {}", ecosystem_str)),
            }
        }
    };

    match ctx.get_package_info(name, ecosystem).await {
        Ok(pkg) => ToolResult {
            success: true,
            result: serde_json::to_value(pkg).unwrap_or(Value::Null),
            error: None,
        },
        Err(e) => ToolResult {
            success: false,
            result: Value::Null,
            error: Some(e.to_string()),
        },
    }
}

/// Handle get_package_examples tool call
///
/// Arguments:
/// - name: string (required) - Package name
/// - ecosystem: string (optional, default: "npm") - Ecosystem
/// - limit: number (optional, default: 5) - Max examples to return
async fn handle_get_package_examples(
    ctx: &SmartPackageContext,
    args: &Value,
) -> ToolResult {
    let name = match args.get("name").and_then(|v| v.as_str()) {
        Some(n) => n,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some("Missing required argument: name".to_string()),
            }
        }
    };

    let ecosystem_str = args
        .get("ecosystem")
        .and_then(|v| v.as_str())
        .unwrap_or("npm");

    let ecosystem = match Ecosystem::from_str(ecosystem_str) {
        Some(e) => e,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some(format!("Invalid ecosystem: {}", ecosystem_str)),
            }
        }
    };

    let limit = args
        .get("limit")
        .and_then(|v| v.as_u64())
        .unwrap_or(5) as usize;

    match ctx.get_package_examples(name, ecosystem, limit).await {
        Ok(examples) => ToolResult {
            success: true,
            result: serde_json::to_value(examples).unwrap_or(Value::Null),
            error: None,
        },
        Err(e) => ToolResult {
            success: false,
            result: Value::Null,
            error: Some(e.to_string()),
        },
    }
}

/// Handle get_package_patterns tool call
///
/// Arguments:
/// - name: string (required) - Package name
async fn handle_get_package_patterns(
    ctx: &SmartPackageContext,
    args: &Value,
) -> ToolResult {
    let name = match args.get("name").and_then(|v| v.as_str()) {
        Some(n) => n,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some("Missing required argument: name".to_string()),
            }
        }
    };

    match ctx.get_package_patterns(name).await {
        Ok(patterns) => ToolResult {
            success: true,
            result: serde_json::to_value(patterns).unwrap_or(Value::Null),
            error: None,
        },
        Err(e) => ToolResult {
            success: false,
            result: Value::Null,
            error: Some(e.to_string()),
        },
    }
}

/// Handle search_patterns tool call
///
/// Arguments:
/// - query: string (required) - Natural language search query
/// - limit: number (optional, default: 10) - Max results to return
async fn handle_search_patterns(
    ctx: &SmartPackageContext,
    args: &Value,
) -> ToolResult {
    let query = match args.get("query").and_then(|v| v.as_str()) {
        Some(q) => q,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some("Missing required argument: query".to_string()),
            }
        }
    };

    let limit = args
        .get("limit")
        .and_then(|v| v.as_u64())
        .unwrap_or(10) as usize;

    match ctx.search_patterns(query, limit).await {
        Ok(results) => ToolResult {
            success: true,
            result: serde_json::to_value(results).unwrap_or(Value::Null),
            error: None,
        },
        Err(e) => ToolResult {
            success: false,
            result: Value::Null,
            error: Some(e.to_string()),
        },
    }
}

/// Handle analyze_file tool call
///
/// Arguments:
/// - content: string (required) - File content to analyze
/// - file_type: string (required) - File type (javascript, python, rust, elixir, etc.)
async fn handle_analyze_file(
    ctx: &SmartPackageContext,
    args: &Value,
) -> ToolResult {
    let content = match args.get("content").and_then(|v| v.as_str()) {
        Some(c) => c,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some("Missing required argument: content".to_string()),
            }
        }
    };

    let file_type_str = match args.get("file_type").and_then(|v| v.as_str()) {
        Some(ft) => ft,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some("Missing required argument: file_type".to_string()),
            }
        }
    };

    let file_type = match FileType::from_extension(file_type_str) {
        Some(ft) => ft,
        None => {
            return ToolResult {
                success: false,
                result: Value::Null,
                error: Some(format!("Unknown file type: {}", file_type_str)),
            }
        }
    };

    match ctx.analyze_file(content, file_type).await {
        Ok(suggestions) => ToolResult {
            success: true,
            result: serde_json::to_value(suggestions).unwrap_or(Value::Null),
            error: None,
        },
        Err(e) => ToolResult {
            success: false,
            result: Value::Null,
            error: Some(e.to_string()),
        },
    }
}
