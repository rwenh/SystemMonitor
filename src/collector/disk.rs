use crate::models::DiskMetrics;
use anyhow::Result;
use sysinfo::Disks;

pub struct DiskCollector;

impl DiskCollector {
    pub fn new() -> Self {
        Self
    }

    pub async fn collect(&self) -> Result<DiskMetrics> {
        let disks = Disks::new_with_refreshed_list();
        let disk = disks.first().ok_or_else(|| anyhow::anyhow!("No disks"))?;

        let total = disk.total_space();
        let available = disk.available_space();
        let used = total.saturating_sub(available);

        Ok(DiskMetrics {
            total,
            used,
            percent: if total > 0 {
                (used as f32 / total as f32) * 100.0
            } else {
                0.0
            },
            mount_point: disk.mount_point().to_string_lossy().to_string(),
        })
    }
}
