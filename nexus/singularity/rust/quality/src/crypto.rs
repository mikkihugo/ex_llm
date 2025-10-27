//! Cryptographic utilities for SASL implementation
//!
//! This module provides cryptographic primitives and utilities used by
//! various SASL mechanisms, including:
//! - Password hashing (PBKDF2, SCRAM)
//! - Challenge-response computation
//! - Secure random generation
//! - Constant-time comparison

use crate::sasl::{SaslError, constant_time_eq};
use ring::{digest, hmac, pbkdf2, rand as ring_rand};
use serde::{Deserialize, Serialize};

/// Cryptographic hash algorithms supported
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HashAlgorithm {
    /// SHA-256
    Sha256,
    /// SHA-1 (legacy)
    Sha1,
}

/// Password hashing configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PasswordHashConfig {
    /// Hash algorithm to use
    pub algorithm: HashAlgorithm,
    /// Number of PBKDF2 iterations
    pub iterations: u32,
    /// Salt length in bytes
    pub salt_length: usize,
    /// Hash length in bytes
    pub hash_length: usize,
}

impl Default for PasswordHashConfig {
    fn default() -> Self {
        Self {
            algorithm: HashAlgorithm::Sha256,
            iterations: 100_000,
            salt_length: 32,
            hash_length: 32,
        }
    }
}

/// Password hash result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PasswordHash {
    /// Hash algorithm used
    pub algorithm: HashAlgorithm,
    /// Salt used for hashing
    pub salt: Vec<u8>,
    /// Hashed password
    pub hash: Vec<u8>,
    /// Number of iterations used
    pub iterations: u32,
}

/// Generate a cryptographically secure salt
pub fn generate_salt(length: usize) -> Result<Vec<u8>, SaslError> {
    let rng = ring_rand::SystemRandom::new();
    let mut salt = vec![0u8; length];
    ring_rand::generate(&rng, &mut salt)
        .map_err(|_| SaslError::CryptoError)?;
    Ok(salt)
}

/// Hash password using PBKDF2
pub fn hash_password_pbkdf2(
    password: &str,
    salt: &[u8],
    config: &PasswordHashConfig,
) -> Result<PasswordHash, SaslError> {
    let iterations = std::num::NonZeroU32::new(config.iterations)
        .ok_or(SaslError::ConfigurationError)?;

    let mut hash = vec![0u8; config.hash_length];

    match config.algorithm {
        HashAlgorithm::Sha256 => {
            pbkdf2::derive(
                pbkdf2::PBKDF2_HMAC_SHA256,
                iterations,
                salt,
                password.as_bytes(),
                &mut hash,
            );
        }
        HashAlgorithm::Sha1 => {
            pbkdf2::derive(
                pbkdf2::PBKDF2_HMAC_SHA1,
                iterations,
                salt,
                password.as_bytes(),
                &mut hash,
            );
        }
    }

    Ok(PasswordHash {
        algorithm: config.algorithm,
        salt: salt.to_vec(),
        hash,
        iterations: config.iterations,
    })
}

/// Verify password against PBKDF2 hash
pub fn verify_password_pbkdf2(
    password: &str,
    hash: &PasswordHash,
) -> Result<bool, SaslError> {
    let config = PasswordHashConfig {
        algorithm: hash.algorithm,
        iterations: hash.iterations,
        salt_length: hash.salt.len(),
        hash_length: hash.hash.len(),
    };

    let computed_hash = hash_password_pbkdf2(password, &hash.salt, &config)?;
    Ok(constant_time_eq(&computed_hash.hash, &hash.hash))
}

/// Compute HMAC for challenge-response authentication
pub fn compute_hmac(key: &[u8], message: &[u8], algorithm: HashAlgorithm) -> Result<Vec<u8>, SaslError> {
    let key = hmac::Key::new(match algorithm {
        HashAlgorithm::Sha256 => hmac::HMAC_SHA256,
        HashAlgorithm::Sha1 => hmac::HMAC_SHA1,
    }, key);

    let mut result = vec![0u8; match algorithm {
        HashAlgorithm::Sha256 => 32,
        HashAlgorithm::Sha1 => 20,
    }];

    hmac::sign(&key, message, &mut result);
    Ok(result.to_vec())
}

/// Verify HMAC
pub fn verify_hmac(
    key: &[u8],
    message: &[u8],
    expected_hmac: &[u8],
    algorithm: HashAlgorithm,
) -> Result<bool, SaslError> {
    let computed_hmac = compute_hmac(key, message, algorithm)?;
    Ok(constant_time_eq(&computed_hmac, expected_hmac))
}

/// Generate SCRAM client proof
pub fn generate_scram_client_proof(
    password: &str,
    salt: &[u8],
    iterations: u32,
    client_nonce: &str,
    server_nonce: &str,
    channel_binding: &str,
) -> Result<Vec<u8>, SaslError> {
    // SCRAM-SHA-256 implementation
    let config = PasswordHashConfig {
        algorithm: HashAlgorithm::Sha256,
        iterations,
        salt_length: salt.len(),
        hash_length: 32,
    };

    let salted_password = hash_password_pbkdf2(password, salt, &config)?;

    // Client Key = HMAC(SaltedPassword, "Client Key")
    let client_key = compute_hmac(&salted_password.hash, b"Client Key", HashAlgorithm::Sha256)?;

    // Stored Key = H(Client Key)
    let stored_key = digest::digest(&digest::SHA256, &client_key);

    // Auth Message = client-first-message-bare + "," + server-first-message + "," + client-final-message-without-proof
    let auth_message = format!(
        "n={},r={},r={},s={},i={},c={},r={}",
        "user", // username would be passed in
        client_nonce,
        server_nonce,
        base64::encode(salt),
        iterations,
        channel_binding,
        server_nonce
    );

    // Client Signature = HMAC(StoredKey, AuthMessage)
    let client_signature = compute_hmac(&stored_key.as_ref(), auth_message.as_bytes(), HashAlgorithm::Sha256)?;

    // Client Proof = ClientKey XOR ClientSignature
    let client_proof = client_key.iter()
        .zip(client_signature.iter())
        .map(|(a, b)| a ^ b)
        .collect();

    Ok(client_proof)
}

/// Verify SCRAM client proof
pub fn verify_scram_client_proof(
    password: &str,
    salt: &[u8],
    iterations: u32,
    client_nonce: &str,
    server_nonce: &str,
    channel_binding: &str,
    client_proof: &[u8],
) -> Result<bool, SaslError> {
    let expected_proof = generate_scram_client_proof(
        password,
        salt,
        iterations,
        client_nonce,
        server_nonce,
        channel_binding,
    )?;

    Ok(constant_time_eq(&expected_proof, client_proof))
}

/// Generate server signature for SCRAM
pub fn generate_scram_server_signature(
    password: &str,
    salt: &[u8],
    iterations: u32,
    client_nonce: &str,
    server_nonce: &str,
    channel_binding: &str,
) -> Result<Vec<u8>, SaslError> {
    let config = PasswordHashConfig {
        algorithm: HashAlgorithm::Sha256,
        iterations,
        salt_length: salt.len(),
        hash_length: 32,
    };

    let salted_password = hash_password_pbkdf2(password, salt, &config)?;

    // Server Key = HMAC(SaltedPassword, "Server Key")
    let server_key = compute_hmac(&salted_password.hash, b"Server Key", HashAlgorithm::Sha256)?;

    // Auth Message (same as in client proof)
    let auth_message = format!(
        "n={},r={},r={},s={},i={},c={},r={}",
        "user",
        client_nonce,
        server_nonce,
        base64::encode(salt),
        iterations,
        channel_binding,
        server_nonce
    );

    // Server Signature = HMAC(ServerKey, AuthMessage)
    compute_hmac(&server_key, auth_message.as_bytes(), HashAlgorithm::Sha256)
}

/// Compute Diameter response (HMAC-based)
pub fn compute_diameter_response(
    challenge: &[u8],
    username: &str,
    password: &str,
    timestamp: u64,
) -> Result<Vec<u8>, SaslError> {
    let message = format!("{}:{}:{}", challenge, username, timestamp);
    compute_hmac(password.as_bytes(), message.as_bytes(), HashAlgorithm::Sha256)
}

/// Verify Diameter response
pub fn verify_diameter_response(
    challenge: &[u8],
    username: &str,
    password: &str,
    timestamp: u64,
    response: &[u8],
) -> Result<bool, SaslError> {
    let expected_response = compute_diameter_response(challenge, username, password, timestamp)?;
    Ok(constant_time_eq(&expected_response, response))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_salt() {
        let salt = generate_salt(32).unwrap();
        assert_eq!(salt.len(), 32);
    }

    #[test]
    fn test_hash_password_pbkdf2() {
        let config = PasswordHashConfig::default();
        let hash = hash_password_pbkdf2("password", b"salt", &config).unwrap();

        assert_eq!(hash.algorithm, HashAlgorithm::Sha256);
        assert_eq!(hash.salt.len(), 32);
        assert_eq!(hash.hash.len(), 32);
        assert_eq!(hash.iterations, 100_000);
    }

    #[test]
    fn test_verify_password_pbkdf2() {
        let config = PasswordHashConfig::default();
        let hash = hash_password_pbkdf2("password", b"salt", &config).unwrap();

        assert!(verify_password_pbkdf2("password", &hash).unwrap());
        assert!(!verify_password_pbkdf2("wrong_password", &hash).unwrap());
    }

    #[test]
    fn test_compute_hmac() {
        let key = b"secret_key";
        let message = b"message";
        let hmac = compute_hmac(key, message, HashAlgorithm::Sha256).unwrap();

        assert_eq!(hmac.len(), 32);
    }

    #[test]
    fn test_verify_hmac() {
        let key = b"secret_key";
        let message = b"message";
        let expected_hmac = compute_hmac(key, message, HashAlgorithm::Sha256).unwrap();

        assert!(verify_hmac(key, message, &expected_hmac, HashAlgorithm::Sha256).unwrap());
        assert!(!verify_hmac(key, b"wrong_message", &expected_hmac, HashAlgorithm::Sha256).unwrap());
    }

    #[test]
    fn test_diameter_response() {
        let challenge = b"challenge";
        let username = "test_user";
        let password = "test_password";
        let timestamp = 1234567890;

        let response = compute_diameter_response(challenge, username, password, timestamp).unwrap();
        assert!(verify_diameter_response(challenge, username, password, timestamp, &response).unwrap());
        assert!(!verify_diameter_response(challenge, username, "wrong_password", timestamp, &response).unwrap());
    }
}