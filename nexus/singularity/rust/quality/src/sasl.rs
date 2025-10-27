//! Core SASL functionality and trait definitions
//!
//! This module provides the core SASL functionality including:
//! - SASL mechanism trait definitions
//! - Authentication context management
//! - Session management
//! - Error handling

use crate::{SaslMechanism, SaslResult, SaslChallenge, SaslResponse, SaslConfig};
use ring::{digest, pbkdf2, rand as ring_rand};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// SASL authentication error
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SaslError {
    /// Invalid credentials provided
    InvalidCredentials,
    /// Mechanism not supported
    UnsupportedMechanism,
    /// Authentication failed
    AuthenticationFailed,
    /// Session expired
    SessionExpired,
    /// Invalid challenge or response
    InvalidChallengeResponse,
    /// Cryptographic error
    CryptoError,
    /// Configuration error
    ConfigurationError,
    /// Network error
    NetworkError,
    /// Other error with message
    Other(String),
}

/// SASL authentication context
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslContext {
    /// User identifier
    pub user_id: String,
    /// SASL mechanism used
    pub mechanism: SaslMechanism,
    /// Session identifier
    pub session_id: String,
    /// Authentication timestamp
    pub authenticated_at: u64,
    /// Session timeout in seconds
    pub session_timeout: u64,
    /// User permissions
    pub permissions: Vec<String>,
    /// Additional metadata
    pub metadata: HashMap<String, String>,
}

/// SASL mechanism trait
pub trait SaslMechanismImpl {
    /// Authenticate using this mechanism
    fn authenticate(
        &self,
        credentials: &SaslCredentials,
        config: &SaslConfig,
    ) -> Result<SaslContext, SaslError>;

    /// Generate a challenge for mutual authentication
    fn generate_challenge(&self, config: &SaslConfig) -> Result<SaslChallenge, SaslError>;

    /// Verify response to challenge
    fn verify_response(
        &self,
        challenge: &SaslChallenge,
        response: &SaslResponse,
        config: &SaslConfig,
    ) -> Result<SaslContext, SaslError>;

    /// Get mechanism information
    fn get_info(&self) -> SaslMechanismInfo;
}

/// SASL mechanism information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslMechanismInfo {
    /// Mechanism name
    pub name: String,
    /// Mechanism type
    pub mechanism: SaslMechanism,
    /// Description
    pub description: String,
    /// Supported features
    pub features: Vec<String>,
    /// Security level (1-10)
    pub security_level: u8,
}

/// SASL credentials
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaslCredentials {
    /// Username
    pub username: String,
    /// Password (for password-based auth)
    pub password: Option<String>,
    /// Client nonce (for challenge-response)
    pub client_nonce: Option<String>,
    /// Additional credentials data
    pub additional_data: HashMap<String, String>,
}

/// SASL authentication manager
pub struct SaslManager {
    config: SaslConfig,
    mechanisms: HashMap<SaslMechanism, Box<dyn SaslMechanismImpl>>,
}

impl SaslManager {
    /// Create a new SASL manager with default configuration
    pub fn new() -> Self {
        Self::with_config(SaslConfig::default())
    }

    /// Create a new SASL manager with custom configuration
    pub fn with_config(config: SaslConfig) -> Self {
        let mut mechanisms: HashMap<SaslMechanism, Box<dyn SaslMechanismImpl>> = HashMap::new();

        // Register built-in mechanisms
        mechanisms.insert(SaslMechanism::Diameter, Box::new(crate::diameter::DiameterSasl::new()));
        mechanisms.insert(SaslMechanism::Radius, Box::new(crate::radius::RadiusSasl::new()));
        mechanisms.insert(SaslMechanism::SS7, Box::new(crate::ss7::Ss7Sasl::new()));
        mechanisms.insert(SaslMechanism::Scram, Box::new(crate::scram::ScramSasl::new()));

        Self { config, mechanisms }
    }

    /// Authenticate using specified mechanism
    pub fn authenticate(
        &self,
        credentials: SaslCredentials,
        mechanism: SaslMechanism,
    ) -> Result<SaslContext, SaslError> {
        match self.mechanisms.get(&mechanism) {
            Some(mechanism_impl) => mechanism_impl.authenticate(&credentials, &self.config),
            None => Err(SaslError::UnsupportedMechanism),
        }
    }

    /// Generate challenge for mutual authentication
    pub fn generate_challenge(
        &self,
        mechanism: SaslMechanism,
    ) -> Result<SaslChallenge, SaslError> {
        match self.mechanisms.get(&mechanism) {
            Some(mechanism_impl) => mechanism_impl.generate_challenge(&self.config),
            None => Err(SaslError::UnsupportedMechanism),
        }
    }

    /// Verify response to challenge
    pub fn verify_response(
        &self,
        challenge: &SaslChallenge,
        response: &SaslResponse,
        mechanism: SaslMechanism,
    ) -> Result<SaslContext, SaslError> {
        match self.mechanisms.get(&mechanism) {
            Some(mechanism_impl) => mechanism_impl.verify_response(challenge, response, &self.config),
            None => Err(SaslError::UnsupportedMechanism),
        }
    }

    /// Get supported mechanisms
    pub fn supported_mechanisms(&self) -> Vec<SaslMechanism> {
        self.mechanisms.keys().cloned().collect()
    }

    /// Get mechanism information
    pub fn get_mechanism_info(&self, mechanism: SaslMechanism) -> Option<SaslMechanismInfo> {
        self.mechanisms.get(&mechanism).map(|m| m.get_info())
    }
}

/// Generate a cryptographically secure random session ID
pub fn generate_session_id() -> String {
    let rng = ring_rand::SystemRandom::new();
    let mut session_id = [0u8; 32];
    ring_rand::generate(&rng, &mut session_id).expect("Failed to generate random session ID");
    hex::encode(session_id)
}

/// Generate a cryptographically secure nonce
pub fn generate_nonce(size: usize) -> Result<Vec<u8>, SaslError> {
    let rng = ring_rand::SystemRandom::new();
    let mut nonce = vec![0u8; size];
    ring_rand::generate(&rng, &mut nonce)
        .map_err(|_| SaslError::CryptoError)?;
    Ok(nonce)
}

/// Hash password using PBKDF2
pub fn hash_password(password: &str, salt: &[u8], iterations: u32) -> Result<Vec<u8>, SaslError> {
    let mut hash = vec![0u8; digest::SHA256_OUTPUT_LEN];
    pbkdf2::derive(
        pbkdf2::PBKDF2_HMAC_SHA256,
        std::num::NonZeroU32::new(iterations).ok_or(SaslError::ConfigurationError)?,
        salt,
        password.as_bytes(),
        &mut hash,
    );
    Ok(hash)
}

/// Verify password against hash
pub fn verify_password(password: &str, hash: &[u8], salt: &[u8], iterations: u32) -> Result<bool, SaslError> {
    let computed_hash = hash_password(password, salt, iterations)?;
    Ok(constant_time_eq(&computed_hash, hash))
}

/// Constant-time equality check to prevent timing attacks
pub fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }

    let mut result = 0u8;
    for i in 0..a.len() {
        result |= a[i] ^ b[i];
    }

    result == 0
}

/// Validate SASL credentials
pub fn validate_credentials(credentials: &SaslCredentials) -> Result<(), SaslError> {
    if credentials.username.is_empty() {
        return Err(SaslError::InvalidCredentials);
    }

    if credentials.username.len() > 255 {
        return Err(SaslError::InvalidCredentials);
    }

    // Check for valid characters in username
    if !credentials.username.chars().all(|c| c.is_alphanumeric() || c == '_' || c == '-' || c == '.') {
        return Err(SaslError::InvalidCredentials);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_session_id() {
        let session_id = generate_session_id();
        assert_eq!(session_id.len(), 64); // 32 bytes * 2 hex chars per byte
    }

    #[test]
    fn test_generate_nonce() {
        let nonce = generate_nonce(32).unwrap();
        assert_eq!(nonce.len(), 32);
    }

    #[test]
    fn test_hash_password() {
        let password = "test_password";
        let salt = b"test_salt";
        let hash = hash_password(password, salt, 1000).unwrap();
        assert_eq!(hash.len(), digest::SHA256_OUTPUT_LEN);
    }

    #[test]
    fn test_verify_password() {
        let password = "test_password";
        let salt = b"test_salt";
        let hash = hash_password(password, salt, 1000).unwrap();

        assert!(verify_password(password, &hash, salt, 1000).unwrap());
        assert!(!verify_password("wrong_password", &hash, salt, 1000).unwrap());
    }

    #[test]
    fn test_constant_time_eq() {
        let a = [1, 2, 3, 4];
        let b = [1, 2, 3, 4];
        let c = [1, 2, 3, 5];

        assert!(constant_time_eq(&a, &b));
        assert!(!constant_time_eq(&a, &c));
    }

    #[test]
    fn test_validate_credentials() {
        let valid_credentials = SaslCredentials {
            username: "test_user".to_string(),
            password: Some("password".to_string()),
            client_nonce: None,
            additional_data: HashMap::new(),
        };

        assert!(validate_credentials(&valid_credentials).is_ok());

        let invalid_credentials = SaslCredentials {
            username: "".to_string(),
            password: None,
            client_nonce: None,
            additional_data: HashMap::new(),
        };

        assert!(validate_credentials(&invalid_credentials).is_err());
    }
}