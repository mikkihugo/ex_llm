#[derive(Debug, Clone)]
pub struct AstGrepConfig {
    pub max_file_size: usize,
    pub cache_size: usize,
    pub timeout_ms: u64,
    pub enable_caching: bool,
    pub enable_parallel: bool,
    pub max_workers: usize,
}

impl Default for AstGrepConfig {
    fn default() -> Self {
        Self {
            max_file_size: 10 * 1024 * 1024,
            cache_size: 1024,
            timeout_ms: 5_000,
            enable_caching: true,
            enable_parallel: true,
            max_workers: num_cpus::get().max(1),
        }
    }
}
