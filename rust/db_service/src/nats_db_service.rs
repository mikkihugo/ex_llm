/*!
 * NATS Database Service
 *
 * Owns PostgreSQL, handles all DB operations via NATS request/reply.
 * Other services never connect to PostgreSQL directly.
 */

use anyhow::Result;
use async_nats::jetstream;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use tracing::{info, error};

#[derive(Debug, Serialize, Deserialize)]
pub struct DbQuery {
    pub sql: String,
    pub params: Vec<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DbResponse {
    pub rows: Vec<serde_json::Value>,
    pub rows_affected: Option<u64>,
}

pub struct NatsDbService {
    pool: PgPool,
    nats: async_nats::Client,
}

impl NatsDbService {
    pub async fn new(database_url: &str, nats_url: &str) -> Result<Self> {
        // Connect to PostgreSQL
        let pool = PgPool::connect(database_url).await?;

        // Run migrations
        sqlx::migrate!("./migrations").run(&pool).await?;

        // Connect to NATS
        let nats = async_nats::connect(nats_url).await?;

        info!("✅ Connected to PostgreSQL + NATS");

        Ok(Self { pool, nats })
    }

    /// Handle database query requests from NATS
    pub async fn handle_db_requests(&self) -> Result<()> {
        let subscriber = self.nats.subscribe("db.query").await?;

        info!("👂 Listening for DB queries on db.query");

        let pool = self.pool.clone();
        let nats = self.nats.clone();

        tokio::spawn(async move {
            while let Some(msg) = subscriber.next().await {
                if let Some(reply) = msg.reply {
                    let query: DbQuery = match serde_json::from_slice(&msg.payload) {
                        Ok(q) => q,
                        Err(e) => {
                            error!("Failed to parse query: {}", e);
                            continue;
                        }
                    };

                    // Execute query
                    let response = Self::execute_query(&pool, query).await;

                    let response_bytes = serde_json::to_vec(&response).unwrap_or_default();
                    let _ = nats.publish(reply, response_bytes.into()).await;
                }
            }
        });

        Ok(())
    }

    /// Handle codebase snapshot inserts from detection system
    pub async fn handle_codebase_snapshots(&self) -> Result<()> {
        let subscriber = self.nats.subscribe("db.insert.codebase_snapshots").await?;

        info!("👂 Listening for codebase snapshots on db.insert.codebase_snapshots");

        let pool = self.pool.clone();

        tokio::spawn(async move {
            while let Some(msg) = subscriber.next().await {
                let snapshot: serde_json::Value = match serde_json::from_slice(&msg.payload) {
                    Ok(s) => s,
                    Err(e) => {
                        error!("Failed to parse snapshot: {}", e);
                        continue;
                    }
                };

                // Insert snapshot into Postgres
                if let Err(e) = Self::insert_snapshot(&pool, snapshot).await {
                    error!("Failed to insert snapshot: {}", e);
                }
            }
        });

        Ok(())
    }

    /// Insert codebase snapshot into Postgres
    async fn insert_snapshot(pool: &PgPool, snapshot: serde_json::Value) -> Result<()> {
        let codebase_id = snapshot["codebase_id"].as_str().unwrap_or("unknown");
        let snapshot_id = snapshot["snapshot_id"].as_i64().unwrap_or(0);
        let metadata = snapshot["metadata"].clone();
        let summary = snapshot["summary"].clone();
        let detected = &snapshot["detected_technologies"];
        let features = snapshot["features"].clone();

        sqlx::query!(
            r#"
            INSERT INTO codebase_snapshots (
                codebase_id, snapshot_id, metadata, summary,
                detected_technologies, features, inserted_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, NOW())
            ON CONFLICT (codebase_id, snapshot_id)
            DO UPDATE SET
                metadata = EXCLUDED.metadata,
                summary = EXCLUDED.summary,
                detected_technologies = EXCLUDED.detected_technologies,
                features = EXCLUDED.features
            "#,
            codebase_id,
            snapshot_id,
            metadata,
            summary,
            detected.as_array().unwrap_or(&vec![]).iter()
                .filter_map(|v| v.as_str())
                .collect::<Vec<_>>(),
            features
        )
        .execute(pool)
        .await?;

        info!("✅ Inserted snapshot: {}:{}", codebase_id, snapshot_id);
        Ok(())
    }

    /// Handle database insert/update/delete requests
    pub async fn handle_db_mutations(&self) -> Result<()> {
        let subscriber = self.nats.subscribe("db.execute").await?;

        info!("👂 Listening for DB mutations on db.execute");

        let pool = self.pool.clone();
        let nats = self.nats.clone();

        tokio::spawn(async move {
            while let Some(msg) = subscriber.next().await {
                if let Some(reply) = msg.reply {
                    let query: DbQuery = match serde_json::from_slice(&msg.payload) {
                        Ok(q) => q,
                        Err(e) => {
                            error!("Failed to parse mutation: {}", e);
                            continue;
                        }
                    };

                    // Execute mutation
                    let response = Self::execute_mutation(&pool, query).await;

                    let response_bytes = serde_json::to_vec(&response).unwrap_or_default();
                    let _ = nats.publish(reply, response_bytes.into()).await;
                }
            }
        });

        Ok(())
    }

    async fn execute_query(pool: &PgPool, query: DbQuery) -> DbResponse {
        // Execute SQL query
        match sqlx::query(&query.sql).fetch_all(pool).await {
            Ok(rows) => {
                let json_rows: Vec<serde_json::Value> = rows
                    .iter()
                    .map(|row| {
                        // Convert PostgreSQL row to JSON
                        // This is a simplified version - needs proper column mapping
                        serde_json::json!({})
                    })
                    .collect();

                DbResponse {
                    rows: json_rows,
                    rows_affected: None,
                }
            }
            Err(e) => {
                error!("Query failed: {}", e);
                DbResponse {
                    rows: vec![],
                    rows_affected: None,
                }
            }
        }
    }

    async fn execute_mutation(pool: &PgPool, query: DbQuery) -> DbResponse {
        // Execute INSERT/UPDATE/DELETE
        match sqlx::query(&query.sql).execute(pool).await {
            Ok(result) => DbResponse {
                rows: vec![],
                rows_affected: Some(result.rows_affected()),
            },
            Err(e) => {
                error!("Mutation failed: {}", e);
                DbResponse {
                    rows: vec![],
                    rows_affected: Some(0),
                }
            }
        }
    }
}
