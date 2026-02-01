use crate::models::ProcessInfo;
use anyhow::Result;
use sysinfo::System;

pub struct ProcessCollector;

impl ProcessCollector {
    pub fn new() -> Self {
        Self
    }

    pub async fn collect(&self) -> Result<Vec<ProcessInfo>> {
        let mut sys = System::new_all();
        sys.refresh_all();

        let mut procs: Vec<ProcessInfo> = sys
            .processes()
            .iter()
            .map(|(pid, proc)| ProcessInfo {
                pid: pid.as_u32(),
                name: proc.name().to_string_lossy().to_string(),
                cpu_usage: proc.cpu_usage(),
                memory: proc.memory(),
            })
            .collect();

        procs.sort_by(|a, b| b.cpu_usage.partial_cmp(&a.cpu_usage).unwrap());
        procs.truncate(50);

        Ok(procs)
    }
}
