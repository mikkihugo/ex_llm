pub struct Fact {
  engine: EngineFact,
  cache: Arc<RwLock<Cache>>,
}
pub struct FactConfig {
  /// Engine configuration
  pub engine_config: engine::EngineConfig,

  /// Cache size in bytes
  pub cache_size: usize,

  /// Enable performance monitoring
  pub enable_monitoring: bool,

  /// Maximum processing timeout
  pub timeout: Option<Duration>,
}
