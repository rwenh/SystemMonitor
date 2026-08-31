//! Note on memory: every []const u8 / slice field here (brand, mount_point,
//! process name, the processes slice itself) is allocated out of the per-tick
//! arena that main.zig resets before each collection pass. Callers
//! must not hold onto a SystemMetrics value past the next arena reset.

const std = @import("std");

pub const CpuMetrics = struct {
    brand: []const u8,
    usage_percent: f32,
    core_count: usize,
};

pub const MemoryMetrics = struct {
    total: u64,
    used: u64,
    percent: f32,
};

pub const DiskMetrics = struct {
    total: u64,
    used: u64,
    percent: f32,
    mount_point: []const u8,
};

pub const NetworkMetrics = struct {
    bytes_recv: u64,
    bytes_sent: u64,
    packets_recv: u64,
    packets_sent: u64,
};

pub const ProcessInfo = struct {
    pid: u32,
    name: []const u8,
    cpu_usage: f32,
    memory: u64,
};

pub const SystemMetrics = struct {
    cpu: CpuMetrics,
    memory: MemoryMetrics,
    disk: DiskMetrics,
    network: NetworkMetrics,
    processes: []ProcessInfo,
    timestamp: i64,
};
