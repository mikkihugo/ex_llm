//! SASL (Simple Authentication and Security Layer) implementation for Singularity
//!
//! This crate provides high-performance SASL authentication mechanisms for
//! telecommunications systems, including Diameter, RADIUS, and SS7 protocols.
//!
//! ## Features
//!
//! - **Diameter SASL**: Challenge-response authentication for 3G/4G/5G networks
//! - **RADIUS SASL**: PAP/CHAP authentication for network access
//! - **SS7 SASL**: SCCP/TCAP authentication for legacy telecom systems
//! - **SCRAM SASL**: Standard SCRAM authentication (PostgreSQL compatible)
//! - **High Performance**: Cryptographic operations optimized for telecom workloads
//! - **Memory Safe**: Zero unsafe code, comprehensive error handling
//!
//! ## Architecture
//!
//! The SASL implementation is organized into several modules:
//!
//! - `sasl`: Core SASL functionality and trait definitions
//! - `diameter`: Diameter protocol SASL mechanism
//! - `radius`: RADIUS protocol SASL mechanism
//! - `ss7`: SS7 protocol SASL mechanism
//! - `scram`: SCRAM protocol SASL mechanism
//! - `crypto`: Cryptographic utilities and primitives
//!
//! ## Integration with Elixir
//!
//! This Rust crate integrates with the Elixir `Singularity.Infrastructure.Sasl` module
//! via Rustler NIFs, providing high-performance cryptographic operations while
//! maintaining the flexibility of Elixir for protocol handling.

pub mod sasl;
pub mod diameter;
pub mod radius;
pub mod ss7;
pub mod scram;
pub mod crypto;

use serde::{Deserialize, Serialize};

/// SASL mechanism types supported by this implementation
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SaslMechanism {
    /// Diameter protocol authentication
    Diameter,
    /// RADIUS protocol authentication
    Radius,
    /// SS7 protocol authentication
    SS7,
    /// SCRAM protocol authentication (standard)
    Scram,
}

/// SASL authentication result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslResult {
    /// Whether authentication was successful
    pub success: bool,
    /// SASL mechanism used
    pub mechanism: SaslMechanism,
    /// Session identifier (if successful)
    pub session_id: Option<String>,
    /// Error message (if failed)
    pub error: Option<String>,
    /// Additional metadata
    pub metadata: std::collections::HashMap<String, String>,
}

/// SASL challenge for mutual authentication
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslChallenge {
    /// Challenge data
    pub data: Vec<u8>,
    /// Challenge type
    pub challenge_type: String,
    /// Timestamp when challenge was generated
    pub timestamp: u64,
}

/// SASL response to challenge
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslResponse {
    /// Response data
    pub data: Vec<u8>,
    /// Response type
    pub response_type: String,
    /// Timestamp when response was generated
    pub timestamp: u64,
}

/// Configuration for SASL mechanisms
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslConfig {
    /// Default mechanism to use
    pub default_mechanism: SaslMechanism,
    /// Supported mechanisms
    pub supported_mechanisms: Vec<SaslMechanism>,
    /// Security settings
    pub security: SecurityConfig,
    /// Telecom-specific settings
    pub telecom: TelecomConfig,
}

/// Security configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityConfig {
    /// Minimum password length
    pub min_password_length: usize,
    /// Whether to require special characters
    pub require_special_chars: bool,
    /// Maximum authentication attempts per minute
    pub max_auth_attempts_per_minute: u32,
    /// Default session timeout in seconds
    pub default_session_timeout: u64,
    /// Maximum session timeout in seconds
    pub max_session_timeout: u64,
}

/// Telecom-specific configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelecomConfig {
    /// Enable telecom protocol support
    pub enable_telecom_protocols: bool,
    /// Supported telecom protocols
    pub protocols: Vec<String>,
    /// Network Access Server configuration
    pub nas: NasConfig,
    /// SS7 configuration
    pub ss7: Ss7Config,
}

/// Network Access Server configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NasConfig {
    /// Default NAS identifier
    pub default_identifier: String,
    /// NAS IP address
    pub ip_address: Option<String>,
    /// Supported authentication methods
    pub auth_methods: Vec<String>,
}

/// SS7 configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ss7Config {
    /// Default point code
    pub default_point_code: String,
    /// Default subsystem number
    pub default_subsystem: u8,
    /// Enable global title translation
    pub global_title_translation: bool,
}

impl Default for SaslConfig {
    fn default() -> Self {
        Self {
            default_mechanism: SaslMechanism::Diameter,
            supported_mechanisms: vec![
                SaslMechanism::Diameter,
                SaslMechanism::Radius,
                SaslMechanism::SS7,
                SaslMechanism::Scram,
            ],
            security: SecurityConfig::default(),
            telecom: TelecomConfig::default(),
        }
    }
}

impl Default for SecurityConfig {
    fn default() -> Self {
        Self {
            min_password_length: 12,
            require_special_chars: true,
            max_auth_attempts_per_minute: 5,
            default_session_timeout: 3600,  // 1 hour
            max_session_timeout: 86400,     // 24 hours
        }
    }
}

impl Default for TelecomConfig {
    fn default() -> Self {
        Self {
            enable_telecom_protocols: true,
            protocols: vec![
                "diameter".to_string(),
                "radius".to_string(),
                "ss7".to_string(),
                "sigtran".to_string(),
            ],
            nas: NasConfig::default(),
            ss7: Ss7Config::default(),
        }
    }
}

impl Default for NasConfig {
    fn default() -> Self {
        Self {
            default_identifier: "singularity-nas".to_string(),
            ip_address: None,
            auth_methods: vec!["pap".to_string(), "chap".to_string(), "mschap".to_string()],
        }
    }
}

impl Default for Ss7Config {
    fn default() -> Self {
        Self {
            default_point_code: "1-234-5".to_string(),
            default_subsystem: 3,
            global_title_translation: true,
        }
    }
}