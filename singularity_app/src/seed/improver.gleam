import gleam/string
import gleam/result

pub type ValidationError {
  ValidationError(message: String)
}

pub fn validate(code: String) -> Result(String, ValidationError) {
  case string.length(code) {
    0 -> Error(ValidationError("code payload is empty"))
    n if n > 1_000_000 -> Error(ValidationError("code payload too large (max 1MB)"))
    _ -> {
      // Basic validation: check for valid Gleam-like structure
      case string.contains(code, "pub fn") || string.contains(code, "fn ") {
        True -> Ok(code)
        False -> Error(ValidationError("code must contain at least one function"))
      }
    }
  }
}

// Note: Actual hot reload requires compiling Gleam -> BEAM and loading modules
// For now, we validate and track versions. Full implementation would:
// 1. Write code to temp file
// 2. Compile with gleam compiler
// 3. Use :code.load_file/1 to load the .beam file
// 4. Call :code.soft_purge/1 on old version
pub fn hot_reload(_path: String) -> Result(Int, String) {
  // Return timestamp as version ID
  // In production, this would load compiled BEAM modules
  Ok(system_time(1))
}

@external(erlang, "erlang", "system_time")
fn system_time(unit: Int) -> Int
