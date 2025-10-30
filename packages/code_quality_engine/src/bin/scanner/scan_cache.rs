use redb::{Database, TableDefinition, ReadableDatabase};
use std::path::PathBuf;

const FILES: TableDefinition<&str, &str> = TableDefinition::new("files");

pub fn open() -> Option<Database> {
    let path = cache_path()?;
    // Safety: single-process CLI access only
    Database::create(path.clone()).ok().or_else(|| Database::open(path).ok())
}

pub fn get(db: &Database, path: &str) -> Option<(String, f64, f64)> {
    let txn = db.begin_read().ok()?;
    let tbl = txn.open_table(FILES).ok()?;
    let val = tbl.get(path).ok()??;
    let s = val.value();
    let v: serde_json::Value = serde_json::from_str(s).ok()?;
    let hash = v.get("hash")?.as_str()?.to_string();
    let mi = v.get("mi")?.as_f64()?;
    let cc = v.get("cc")?.as_f64()?;
    Some((hash, mi, cc))
}

pub fn put(db: &Database, path: &str, hash: &str, mi: f64, cc: f64) {
    if let Ok(mut w) = db.begin_write() {
        if let Ok(mut tbl) = w.open_table(FILES) {
            let v = serde_json::json!({"hash": hash, "mi": mi, "cc": cc});
            let s = v.to_string();
            let _ = tbl.insert(path, s.as_str());
        }
        let _ = w.commit();
    }
}

fn cache_path() -> Option<PathBuf> {
    let dir = dirs::cache_dir()?;
    let d = dir.join("singularity");
    let _ = std::fs::create_dir_all(&d);
    Some(d.join("scan_cache.redb"))
}
