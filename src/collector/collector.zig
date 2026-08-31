//! None of these reads are slow enough that true concurrency would matter:
//! they're all quick /proc reads plus one `df` subprocess.
//! So this just calls them in sequence. If you do add real concurrency later
//! (e.g., std.Thread.spawn per collector), note that process.zig's HashMap is
//! not safe to touch from multiple threads without a lock.
const std = @import("std");
const models = @import("../models.zig");
const CpuCollector = @import("cpu.zig").CpuCollector;
const MemoryCollector = @import("memory.zig").MemoryCollector;
const DiskCollector = @import("disk.zig").DiskCollector;
const NetworkCollector = @import("network.zig").NetworkCollector;
const ProcessCollector = @import("process.zig").ProcessCollector;

pub const Collector = struct {
    cpu: CpuCollector,
    memory: MemoryCollector,
    disk: DiskCollector,
    network: NetworkCollector,
    process: ProcessCollector,

    pub fn init(gpa: std.mem.Allocator) Collector {
        return .{
            .cpu = CpuCollector.init(),
            .memory = MemoryCollector.init(),
            .disk = DiskCollector.init(),
            .network = NetworkCollector.init(),
            .process = ProcessCollector.init(gpa),
        };
    }

    pub fn deinit(self: *Collector) void {
        self.process.deinit();
    }

    pub fn collectAll(self: *Collector, arena: std.mem.Allocator) !models.SystemMetrics {
        const cpu = try self.cpu.collect(arena);
        const memory = try self.memory.collect(arena);
        const disk = try self.disk.collect(arena);
        const network = try self.network.collect(arena);
        const processes = try self.process.collect(arena);

        return models.SystemMetrics{
            .cpu = cpu,
            .memory = memory,
            .disk = disk,
            .network = network,
            .processes = processes,
            .timestamp = std.time.timestamp(),
        };
    }
};
