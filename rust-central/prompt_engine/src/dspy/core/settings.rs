//! # DSPy Settings: Global Configuration Management
//!
//! This module provides a mechanism for managing global settings within the DSPy framework,
//! specifically for the Language Model (LM) and its associated `Adapter`. It uses a
//! `LazyLock` and `RwLock` to ensure safe and efficient access to these shared resources
//! across different parts of the application.
//!
//! The `configure` function is the primary entry point for initializing DSPy's global state,
//! making the configured LM and Adapter available for all DSPy modules.
//!
//! @category dspy-core
//! @safe program
//! @mvp core
//! @complexity low
//! @since 1.0.0

use std::sync::{Arc, RwLock};
use once_cell::sync::Lazy;

use super::LM;
use crate::dspy::{adapter::Adapter, SparcConfig};

/// Holds the global settings for the DSPy framework.
///
/// This includes the configured Language Model (`LM`) and the `Adapter`
/// responsible for communicating with it.
///
/// @category dspy-struct
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
#[derive(Clone)]
pub struct Settings {
  /// The Language Model (LM) instance used by DSPy.
  pub lm: LM,
  /// The adapter responsible for formatting prompts and parsing responses for the LM.
  pub adapter: Arc<dyn Adapter>,
}

impl Default for Settings {
  fn default() -> Self {
    // Create a default LM and adapter for settings
    // SparcConfig replaced with SparcConfig
    use crate::dspy::adapter::ConversationHistoryAdapter;

    Self { lm: LM::new("default".to_string(), SparcConfig::default()), adapter: Arc::new(ConversationHistoryAdapter) }
  }
}

/// A lazily initialized, globally accessible `RwLock` holding the DSPy settings.
///
/// This ensures that the settings are initialized only once and can be safely
/// read by multiple threads, while allowing exclusive write access for configuration.
///
/// @category dspy-global
/// @safe program
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub static GLOBAL_SETTINGS: Lazy<RwLock<Option<Settings>>> = Lazy::new(|| RwLock::new(None));

/// Retrieves the globally configured Language Model (LM).
///
/// This function provides access to the `LM` instance that has been set up
/// via the `configure` function. It will panic if DSPy settings have not
/// been configured yet.
///
/// @returns The configured `LM` instance.
///
/// @category dspy-function
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub fn get_lm() -> LM {
  GLOBAL_SETTINGS.read().expect("Global settings lock poisoned").as_ref().expect("DSPy settings not configured - call configure() first").lm.clone()
}

/// Configures the global DSPy settings with a Language Model (LM) and an Adapter.
///
/// This function initializes the `GLOBAL_SETTINGS` with the provided `LM` and `Adapter`,
/// making them available for all DSPy operations. It should be called once at the
/// application's startup.
///
/// @param lm The Language Model (LM) instance to use.
/// @param adapter The `Adapter` implementation for the LM.
///
/// @category dspy-function
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub fn configure(lm: LM, adapter: impl Adapter + 'static) {
  let settings = Settings { lm, adapter: Arc::new(adapter) };
  *GLOBAL_SETTINGS.write().expect("Global settings lock poisoned") = Some(settings);
}
