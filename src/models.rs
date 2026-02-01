use std::time::SystemTime;

#[derive(Debug, Clone)]
pub struct SystemMetrics {
    pub cpu: CpuMetrics,
    pub memory: MemoryMetrics,
    pub disk: DiskMetrics,
    pub network: NetworkMetrics,
    pub processes: Vec<ProcessInfo>,
    pub timestamp: SystemTime,
}

#[derive(Debug, Clone)]
pub struct CpuMetrics {
    pub brand: String,
    pub usage_percent: f32,
    pub core_count: usize,
}

#[derive(Debug, Clone)]
pub struct MemoryMetrics {
    pub total: u64,
    pub used: u64,
    pub percent: f32,
}

#[derive(Debug, Clone)]
pub struct DiskMetrics {
    pub total: u64,
    pub used: u64,
    pub percent: f32,
    pub mount_point: String,
}

#[derive(Debug, Clone)]
pub struct NetworkMetrics {
    pub bytes_recv: u64,
    pub bytes_sent: u64,
    pub packets_recv: u64,
    pub packets_sent: u64,
}

#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub cpu_usage: f32,
    pub memory: u64,
}
