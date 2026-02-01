use crate::models::CpuMetrics;
use anyhow::Result;
use sysinfo::System;

pub struct CpuCollector;

impl CpuCollector {
    pub fn new() -> Self {
        Self
    }

    pub async fn collect(&self) -> Result<CpuMetrics> {
        let mut sys = System::new_all();
        sys.refresh_all();
        tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
        sys.refresh_all();

        let cpus = sys.cpus();
        Ok(CpuMetrics {
            brand: cpus
                .first()
                .map(|c| c.brand())
                .unwrap_or("Unknown")
                .to_string(),
            usage_percent: sys.global_cpu_usage(),
            core_count: cpus.len(),
        })
    }
}
