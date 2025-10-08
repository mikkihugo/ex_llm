//! Performance Tracking Module
//! 
//! Handles performance monitoring and reporting.
//! Pure analysis - no I/O operations.

use crate::types::*;

/// Performance tracker for code analysis
pub struct PerformanceTracker {
    /// Internal performance metrics
    pub metrics: PerformanceMetrics,
}

impl PerformanceTracker {
    /// Create a new performance tracker
    pub fn new() -> Self {
        Self {
            metrics: PerformanceMetrics::default(),
        }
    }

    /// Get performance report
    pub fn get_performance_report(&self) -> PerformanceReport {
        PerformanceReport {
            total_analysis_time: self.metrics.total_analysis_time,
            average_file_processing_time: self.metrics.average_file_processing_time,
            memory_usage: self.metrics.memory_usage,
            cpu_usage: self.metrics.cpu_usage,
            files_processed: self.metrics.files_processed,
            errors_encountered: self.metrics.errors_encountered,
        }
    }

    /// Record analysis start
    pub fn record_analysis_start(&mut self) {
        self.metrics.analysis_start_time = Some(std::time::Instant::now());
    }

    /// Record analysis end
    pub fn record_analysis_end(&mut self) {
        if let Some(start_time) = self.metrics.analysis_start_time {
            let duration = start_time.elapsed();
            self.metrics.total_analysis_time = duration.as_millis() as u64;
        }
    }

    /// Record file processing
    pub fn record_file_processed(&mut self, processing_time: std::time::Duration) {
        self.metrics.files_processed += 1;
        self.metrics.total_file_processing_time += processing_time.as_millis() as u64;
        self.metrics.average_file_processing_time = 
            self.metrics.total_file_processing_time / self.metrics.files_processed as u64;
    }

    /// Record error
    pub fn record_error(&mut self) {
        self.metrics.errors_encountered += 1;
    }
}

impl Default for PerformanceTracker {
    fn default() -> Self {
        Self::new()
    }
}

/// Performance metrics
#[derive(Debug, Clone, Default)]
pub struct PerformanceMetrics {
    pub total_analysis_time: u64,
    pub average_file_processing_time: u64,
    pub total_file_processing_time: u64,
    pub memory_usage: u64,
    pub cpu_usage: f64,
    pub files_processed: u64,
    pub errors_encountered: u64,
    pub analysis_start_time: Option<std::time::Instant>,
}