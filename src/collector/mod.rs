// This file goes in: src/collector/mod.rs

mod cpu;
mod disk;
mod memory;
mod network;
mod process;

use anyhow::Result;
use tokio::join;

use crate::models::SystemMetrics;

pub struct Collector {
    cpu: cpu::CpuCollector,
    memory: memory::MemoryCollector,
    disk: disk::DiskCollector,
    network: network::NetworkCollector,
    process: process::ProcessCollector,
}

impl Collector {
    pub fn new() -> Self {
        Self {
            cpu: cpu::CpuCollector::new(),
            memory: memory::MemoryCollector::new(),
            disk: disk::DiskCollector::new(),
            network: network::NetworkCollector::new(),
            process: process::ProcessCollector::new(),
        }
    }
    pub async fn collect_all(&self) -> Result<SystemMetrics> {
        let (cpu, mem, disk, net, procs) = join!(
            self.cpu.collect(),
            self.memory.collect(),
            self.disk.collect(),
            self.network.collect(),
            self.process.collect(),
        );
        Ok(SystemMetrics {
            cpu: cpu?,
            memory: mem?,
            disk: disk?,
            network: net?,
            processes: procs?,
            timestamp: std::time::SystemTime::now(),
        })
    }
}
