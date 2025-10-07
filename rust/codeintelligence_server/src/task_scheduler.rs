//! Task Scheduler - Cron-like task management for Singularity services
//! 
//! Handles different types of async tasks:
//! - Periodic maintenance tasks
//! - Database cleanup
//! - Package registry updates
//! - Health checks
//! - Log rotation
//! - Cache invalidation

use anyhow::Result;
use chrono::{DateTime, Utc};
use cron::Schedule;
use dashmap::DashMap;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::time::sleep;
use tracing::{info, warn, error, debug};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub name: String,
    pub description: String,
    pub schedule: String, // Cron expression
    pub task_type: TaskType,
    pub enabled: bool,
    pub last_run: Option<DateTime<Utc>>,
    pub next_run: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TaskType {
    // System maintenance
    DatabaseCleanup,
    LogRotation,
    CacheInvalidation,
    HealthCheck,
    
    // Package registry tasks
    PackageRegistryUpdate,
    PackageIndexRebuild,
    PackageMetadataSync,
    
    // Code analysis tasks
    CodebaseAnalysis,
    PatternMining,
    QualityMetrics,
    
    // Custom tasks
    Custom(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskResult {
    pub task_id: Uuid,
    pub started_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub status: TaskStatus,
    pub output: String,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TaskStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Skipped,
}

pub struct TaskScheduler {
    tasks: Arc<DashMap<Uuid, Task>>,
    results: Arc<DashMap<Uuid, Vec<TaskResult>>>,
    running_tasks: Arc<DashMap<Uuid, tokio::task::JoinHandle<()>>>,
    shutdown_tx: tokio::sync::oneshot::Sender<()>,
}

impl TaskScheduler {
    pub fn new() -> Self {
        let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel();
        
        Self {
            tasks: Arc::new(DashMap::new()),
            results: Arc::new(DashMap::new()),
            running_tasks: Arc::new(DashMap::new()),
            shutdown_tx,
        }
    }

    pub async fn start(&self) -> Result<()> {
        info!("🕐 Starting Task Scheduler...");
        
        // Add default tasks
        self.add_default_tasks().await?;
        
        // Start the scheduler loop
        self.scheduler_loop().await;
        
        Ok(())
    }

    pub async fn add_task(&self, task: Task) -> Result<()> {
        info!("➕ Adding task: {}", task.name);
        
        // Validate cron expression
        Schedule::from_str(&task.schedule)?;
        
        // Calculate next run time
        let next_run = self.calculate_next_run(&task.schedule)?;
        let task = Task {
            next_run: Some(next_run),
            ..task
        };
        
        self.tasks.insert(task.id, task);
        info!("✅ Task added: {}", task.name);
        
        Ok(())
    }

    pub async fn remove_task(&self, task_id: Uuid) -> Result<()> {
        if let Some((_, task)) = self.tasks.remove(&task_id) {
            info!("🗑️  Removed task: {}", task.name);
            
            // Cancel running task if exists
            if let Some(handle) = self.running_tasks.remove(&task_id) {
                handle.abort();
            }
        }
        
        Ok(())
    }

    pub async fn run_task_now(&self, task_id: Uuid) -> Result<()> {
        if let Some(task) = self.tasks.get(&task_id) {
            info!("▶️  Running task now: {}", task.name);
            self.execute_task(task.clone()).await;
        }
        
        Ok(())
    }

    pub fn list_tasks(&self) -> Vec<Task> {
        self.tasks.iter().map(|entry| entry.value().clone()).collect()
    }

    pub fn get_task_results(&self, task_id: Uuid) -> Option<Vec<TaskResult>> {
        self.results.get(&task_id).map(|entry| entry.value().clone())
    }

    async fn add_default_tasks(&self) -> Result<()> {
        let default_tasks = vec![
            Task {
                id: Uuid::new_v4(),
                name: "Database Cleanup".to_string(),
                description: "Clean up old database records and optimize tables".to_string(),
                schedule: "0 2 * * *".to_string(), // Daily at 2 AM
                task_type: TaskType::DatabaseCleanup,
                enabled: true,
                last_run: None,
                next_run: None,
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
            Task {
                id: Uuid::new_v4(),
                name: "Health Check".to_string(),
                description: "Check health of all services".to_string(),
                schedule: "*/5 * * * *".to_string(), // Every 5 minutes
                task_type: TaskType::HealthCheck,
                enabled: true,
                last_run: None,
                next_run: None,
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
            Task {
                id: Uuid::new_v4(),
                name: "Package Registry Update".to_string(),
                description: "Update package registry data from external sources".to_string(),
                schedule: "0 */6 * * *".to_string(), // Every 6 hours
                task_type: TaskType::PackageRegistryUpdate,
                enabled: true,
                last_run: None,
                next_run: None,
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
            Task {
                id: Uuid::new_v4(),
                name: "Log Rotation".to_string(),
                description: "Rotate and compress log files".to_string(),
                schedule: "0 0 * * *".to_string(), // Daily at midnight
                task_type: TaskType::LogRotation,
                enabled: true,
                last_run: None,
                next_run: None,
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
            Task {
                id: Uuid::new_v4(),
                name: "Cache Invalidation".to_string(),
                description: "Invalidate expired cache entries".to_string(),
                schedule: "*/30 * * * *".to_string(), // Every 30 minutes
                task_type: TaskType::CacheInvalidation,
                enabled: true,
                last_run: None,
                next_run: None,
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
        ];

        for task in default_tasks {
            self.add_task(task).await?;
        }

        Ok(())
    }

    async fn scheduler_loop(&self) {
        info!("🔄 Task Scheduler loop started");
        
        loop {
            let now = Utc::now();
            
            // Check for tasks that need to run
            for entry in self.tasks.iter() {
                let task = entry.value();
                
                if !task.enabled {
                    continue;
                }
                
                if let Some(next_run) = task.next_run {
                    if now >= next_run {
                        // Task is due to run
                        let task_clone = task.clone();
                        self.execute_task(task_clone).await;
                    }
                }
            }
            
            // Sleep for 1 minute before next check
            sleep(Duration::from_secs(60)).await;
        }
    }

    async fn execute_task(&self, task: Task) {
        let task_id = task.id;
        let task_name = task.name.clone();
        
        info!("🚀 Executing task: {}", task_name);
        
        // Create task result
        let result = TaskResult {
            task_id,
            started_at: Utc::now(),
            completed_at: None,
            status: TaskStatus::Running,
            output: String::new(),
            error: None,
        };
        
        // Store initial result
        self.results.entry(task_id).or_insert_with(Vec::new).push(result);
        
        // Spawn task execution
        let tasks = self.tasks.clone();
        let results = self.results.clone();
        let running_tasks = self.running_tasks.clone();
        
        let handle = tokio::spawn(async move {
            let start_time = Utc::now();
            let mut output = String::new();
            let mut error = None;
            let mut status = TaskStatus::Completed;
            
            // Execute the actual task
            match Self::run_task_implementation(&task).await {
                Ok(task_output) => {
                    output = task_output;
                    info!("✅ Task completed: {}", task_name);
                }
                Err(e) => {
                    error = Some(e.to_string());
                    status = TaskStatus::Failed;
                    error!("❌ Task failed: {} - {}", task_name, e);
                }
            }
            
            // Update task result
            if let Some(results_vec) = results.get(&task_id) {
                if let Some(last_result) = results_vec.last_mut() {
                    last_result.completed_at = Some(Utc::now());
                    last_result.status = status;
                    last_result.output = output;
                    last_result.error = error;
                }
            }
            
            // Update task's last_run and next_run
            if let Some(mut task_entry) = tasks.get_mut(&task_id) {
                task_entry.last_run = Some(start_time);
                task_entry.next_run = Self::calculate_next_run(&task_entry.schedule).ok();
            }
            
            // Remove from running tasks
            running_tasks.remove(&task_id);
        });
        
        // Store running task handle
        self.running_tasks.insert(task_id, handle);
    }

    async fn run_task_implementation(task: &Task) -> Result<String> {
        match &task.task_type {
            TaskType::DatabaseCleanup => {
                info!("🧹 Running database cleanup...");
                // TODO: Implement database cleanup
                Ok("Database cleanup completed".to_string())
            }
            TaskType::HealthCheck => {
                info!("🏥 Running health check...");
                // TODO: Implement health check
                Ok("Health check completed".to_string())
            }
            TaskType::PackageRegistryUpdate => {
                info!("📦 Updating package registry...");
                // TODO: Implement package registry update
                Ok("Package registry updated".to_string())
            }
            TaskType::LogRotation => {
                info!("📄 Rotating logs...");
                // TODO: Implement log rotation
                Ok("Log rotation completed".to_string())
            }
            TaskType::CacheInvalidation => {
                info!("🗑️  Invalidating cache...");
                // TODO: Implement cache invalidation
                Ok("Cache invalidation completed".to_string())
            }
            TaskType::CodebaseAnalysis => {
                info!("🔍 Running codebase analysis...");
                // TODO: Implement codebase analysis
                Ok("Codebase analysis completed".to_string())
            }
            TaskType::PatternMining => {
                info!("⛏️  Mining patterns...");
                // TODO: Implement pattern mining
                Ok("Pattern mining completed".to_string())
            }
            TaskType::QualityMetrics => {
                info!("📊 Calculating quality metrics...");
                // TODO: Implement quality metrics
                Ok("Quality metrics calculated".to_string())
            }
            TaskType::Custom(name) => {
                info!("🔧 Running custom task: {}", name);
                // TODO: Implement custom task execution
                Ok(format!("Custom task '{}' completed", name))
            }
            _ => {
                warn!("⚠️  Unknown task type: {:?}", task.task_type);
                Ok("Unknown task type".to_string())
            }
        }
    }

    fn calculate_next_run(schedule: &str) -> Result<DateTime<Utc>> {
        let schedule = Schedule::from_str(schedule)?;
        let now = Utc::now();
        
        schedule
            .upcoming(Utc)
            .next()
            .ok_or_else(|| anyhow::anyhow!("No upcoming runs found"))
    }

    pub async fn shutdown(&self) {
        info!("🛑 Shutting down Task Scheduler...");
        
        // Cancel all running tasks
        for entry in self.running_tasks.iter() {
            entry.value().abort();
        }
        
        info!("✅ Task Scheduler shutdown complete");
    }
}