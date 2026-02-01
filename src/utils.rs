const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
pub fn format_bytes(bytes: u64) -> String {
    if bytes == 0 {
        return "0 B".into();
    }
    let mut val = bytes as f64;
    let mut i = 0;
    while val >= 1024.0 && i < UNITS.len() - 1 {
        val /= 1024.0;
        i += 1;
    }
    format!("{:.2} {}", val, UNITS[i])
}

pub fn format_percent(val: f32) -> String {
    format!("{:.1}%", val)
}
