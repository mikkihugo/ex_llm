//! Runtime hardware detection for native Node.js environments

use std::sync::Once;

#[derive(Debug, Clone)]
pub struct RuntimeHardware {
    pub platform: String,
    pub architecture: String,
    pub cpu_cores: u32,
    pub optimization_level: String,
}

static INIT: Once = Once::new();
static mut RUNTIME_HARDWARE: Option<RuntimeHardware> = None;

pub fn get_runtime_hardware() -> &'static RuntimeHardware {
    unsafe {
        INIT.call_once(|| {
            RUNTIME_HARDWARE = Some(detect_runtime_hardware());
        });
        RUNTIME_HARDWARE.as_ref().unwrap()
    }
}

fn detect_runtime_hardware() -> RuntimeHardware {
    RuntimeHardware {
        platform: std::env::consts::OS.to_string(),
        architecture: std::env::consts::ARCH.to_string(),
        cpu_cores: std::thread::available_parallelism()
            .map(|n| n.get() as u32)
            .unwrap_or(1),
        optimization_level: "native-optimized".to_string(),
    }
}
