use crate::models::NetworkMetrics;
use anyhow::Result;
use sysinfo::Networks;

pub struct NetworkCollector;

impl NetworkCollector {
    pub fn new() -> Self {
        Self
    }

    pub async fn collect(&self) -> Result<NetworkMetrics> {
        let nets = Networks::new_with_refreshed_list();

        let mut total_recv = 0;
        let mut total_sent = 0;
        let mut total_packets_recv = 0;
        let mut total_packets_sent = 0;

        for (_, net) in &nets {
            total_recv += net.total_received();
            total_sent += net.total_transmitted();
            total_packets_recv += net.total_packets_received();
            total_packets_sent += net.total_packets_transmitted();
        }

        Ok(NetworkMetrics {
            bytes_recv: total_recv,
            bytes_sent: total_sent,
            packets_recv: total_packets_recv,
            packets_sent: total_packets_sent,
        })
    }
}
