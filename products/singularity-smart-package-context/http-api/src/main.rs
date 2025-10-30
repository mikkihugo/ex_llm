use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use singularity_smart_package_context_backend::*;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing::info;

// Type alias for handler results
type HandlerResult<T> = std::result::Result<T, AppError>;

/// Application state
#[derive(Clone)]
struct AppState {
    ctx: Arc<SmartPackageContext>,
}

/// Error type for handlers
#[derive(Debug)]
enum AppError {
    BadRequest(String),
    PackageNotFound(String),
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_msg) = match self {
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::PackageNotFound(msg) => (StatusCode::NOT_FOUND, msg),
            AppError::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
        };

        (
            status,
            Json(json!({
                "error": error_msg,
            })),
        )
            .into_response()
    }
}

/// Package info query parameters
#[derive(Deserialize)]
struct PackageQuery {
    #[serde(default = "default_ecosystem")]
    ecosystem: String,
}

fn default_ecosystem() -> String {
    "npm".to_string()
}

/// Examples query parameters
#[derive(Deserialize)]
struct ExamplesQuery {
    #[serde(default = "default_ecosystem")]
    ecosystem: String,
    #[serde(default = "default_limit")]
    limit: usize,
}

fn default_limit() -> usize {
    5
}

/// Search query parameters
#[derive(Deserialize)]
struct SearchQuery {
    q: String,
    #[serde(default = "default_search_limit")]
    limit: usize,
}

fn default_search_limit() -> usize {
    10
}

/// Analyze request body
#[derive(Deserialize)]
struct AnalyzeRequest {
    content: String,
    #[serde(default)]
    file_type: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("info".parse()?),
        )
        .init();

    // Create backend context
    let ctx = SmartPackageContext::new().await?;
    let state = AppState {
        ctx: Arc::new(ctx),
    };

    info!("Initializing Smart Package Context HTTP API");

    // Build router
    let app = Router::new()
        // Health check
        .route("/health", get(health_check))
        // Package info endpoints
        .route("/api/package/:name", get(get_package_info))
        .route("/api/package/:name/examples", get(get_package_examples))
        .route("/api/package/:name/patterns", get(get_package_patterns))
        // Pattern search
        .route("/api/patterns/search", get(search_patterns))
        // Code analysis
        .route("/api/analyze", post(analyze_code))
        // Root endpoint
        .route("/", get(root))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:8888")
        .await?;

    info!("Server listening on http://127.0.0.1:8888");
    info!("API documentation: http://127.0.0.1:8888/");

    axum::serve(listener, app).await?;

    Ok(())
}

// ============================================================================
// Handlers
// ============================================================================

/// Root endpoint with API documentation
async fn root() -> Json<Value> {
    Json(json!({
        "name": "Singularity Smart Package Context",
        "version": "0.1.0",
        "description": "Know before you code - Package intelligence powered by community consensus",
        "endpoints": {
            "health": "GET /health",
            "package_info": "GET /api/package/:name?ecosystem=npm",
            "package_examples": "GET /api/package/:name/examples?ecosystem=npm&limit=5",
            "package_patterns": "GET /api/package/:name/patterns",
            "search_patterns": "GET /api/patterns/search?q=query&limit=10",
            "analyze_code": "POST /api/analyze",
        },
        "docs": "See README.md for complete API documentation"
    }))
}

/// Health check endpoint
async fn health_check() -> Json<Value> {
    Json(json!({
        "status": "healthy",
        "version": "0.1.0"
    }))
}

/// Get package information
async fn get_package_info(
    State(state): State<AppState>,
    Path(name): Path<String>,
    Query(params): Query<PackageQuery>,
) -> HandlerResult<Json<Value>> {
    info!("GET /api/package/{} (ecosystem={})", name, params.ecosystem);

    let ecosystem = match Ecosystem::from_str(&params.ecosystem) {
        Some(eco) => eco,
        None => return Err(AppError::BadRequest(format!("Unknown ecosystem: {}", params.ecosystem))),
    };

    let package = state.ctx.get_package_info(&name, ecosystem)
        .await
        .map_err(|e| AppError::PackageNotFound(format!("{}", e)))?;

    Ok(Json(json!({
        "success": true,
        "data": package,
    })))
}

/// Get package examples
async fn get_package_examples(
    State(state): State<AppState>,
    Path(name): Path<String>,
    Query(params): Query<ExamplesQuery>,
) -> HandlerResult<Json<Value>> {
    info!("GET /api/package/{}/examples (limit={})", name, params.limit);

    let ecosystem = match Ecosystem::from_str(&params.ecosystem) {
        Some(eco) => eco,
        None => return Err(AppError::BadRequest(format!("Unknown ecosystem: {}", params.ecosystem))),
    };

    let examples = state.ctx.get_package_examples(&name, ecosystem, params.limit)
        .await
        .map_err(|e| AppError::Internal(format!("{}", e)))?;

    Ok(Json(json!({
        "success": true,
        "data": examples,
    })))
}

/// Get package patterns
async fn get_package_patterns(
    State(state): State<AppState>,
    Path(name): Path<String>,
) -> HandlerResult<Json<Value>> {
    info!("GET /api/package/{}/patterns", name);

    let patterns = state.ctx.get_package_patterns(&name)
        .await
        .map_err(|e| AppError::Internal(format!("{}", e)))?;

    Ok(Json(json!({
        "success": true,
        "data": patterns,
    })))
}

/// Search patterns
async fn search_patterns(
    State(state): State<AppState>,
    Query(params): Query<SearchQuery>,
) -> HandlerResult<Json<Value>> {
    info!("GET /api/patterns/search?q={}", params.q);

    let results = state.ctx.search_patterns(&params.q, params.limit)
        .await
        .map_err(|e| AppError::Internal(format!("{}", e)))?;

    Ok(Json(json!({
        "success": true,
        "data": results,
    })))
}

/// Analyze code
async fn analyze_code(
    State(state): State<AppState>,
    Json(payload): Json<AnalyzeRequest>,
) -> HandlerResult<Json<Value>> {
    info!("POST /api/analyze ({} bytes)", payload.content.len());

    let file_type = payload.file_type.unwrap_or_else(|| "unknown".to_string());

    // Try to detect file type from extension
    let detected_type = FileType::from_extension(&file_type)
        .unwrap_or(FileType::JavaScript); // Default to JavaScript if unknown

    let suggestions = state.ctx.analyze_file(&payload.content, detected_type)
        .await
        .map_err(|e| AppError::Internal(format!("{}", e)))?;

    Ok(Json(json!({
        "success": true,
        "data": suggestions,
    })))
}
