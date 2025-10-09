//! Minimal deterministic embedding engine.
//!
//! Instead of relying on large GPU models (which weren't checked into the
//! repository), we derive embeddings by hashing the input text and expanding
//! the digest into a fixed-length f32 vector. This keeps the NIF lightweight
//! while giving downstream Elixir code consistent deterministic output for
//! tests and demos.

use rand::{Rng, SeedableRng};
use rand_chacha::ChaCha20Rng;
use rustler::Error;
use sha2::{Digest, Sha256};

const EMBEDDING_DIM: usize = 128;

fn embedding_for_text(text: &str, model: &str) -> Vec<f32> {
    let mut hasher = Sha256::new();
    hasher.update(model.as_bytes());
    hasher.update(b"::");
    hasher.update(text.as_bytes());
    let digest = hasher.finalize();

    let mut seed_bytes = [0u8; 32];
    seed_bytes.copy_from_slice(&digest);
    let mut rng = ChaCha20Rng::from_seed(seed_bytes);

    (0..EMBEDDING_DIM)
        .map(|_| {
            // Generate reproducible float in [-1.0, 1.0]
            let value: f32 = rng.gen::<f32>();
            (value * 2.0) - 1.0
        })
        .collect()
}

#[rustler::nif]
fn embed_single(text: String, model: String) -> Result<Vec<f32>, Error> {
    Ok(embedding_for_text(&text, &model))
}

#[rustler::nif]
fn embed_batch(texts: Vec<String>, model: String) -> Result<Vec<Vec<f32>>, Error> {
    Ok(texts
        .into_iter()
        .map(|text| embedding_for_text(&text, &model))
        .collect())
}

rustler::init!("Elixir.Singularity.EmbeddingEngine", [embed_single, embed_batch]);
