use crate::models::MemoryMetrics;
use anyhow::Result;
use sysinfo::System;

pub struct MemoryCollector;

impl MemoryCollector {
    pub fn new() -> Self {
        Self
    }

    pub async fn collect(&self) -> Result<MemoryMetrics> {
        let mut sys = System::new_all();
        sys.refresh_memory();

        let total = sys.total_memory();
        let used = sys.used_memory();
        Ok(MemoryMetrics {
            total,
            used,
            percent: if total > 0 {
                (used as f32 / total as f32) * 100.0
            } else {
                0.0
            },
        })
    }
}
