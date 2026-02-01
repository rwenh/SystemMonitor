// This file goes in: src/ui/mod.rs

use anyhow::Result;

use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph},
    Frame, Terminal,
};
use std::io;

use crate::{controller::Controller, models::SystemMetrics, utils};

pub struct Ui {
    terminal: Terminal<CrosstermBackend<io::Stdout>>,
}

impl Ui {
    pub fn new() -> Result<Self> {
        let backend = CrosstermBackend::new(io::stdout());
        let terminal = Terminal::new(backend)?;
        Ok(Self { terminal })
    }

    pub fn render(&mut self, metrics: &SystemMetrics, controller: &Controller) -> Result<()> {
        self.terminal.draw(|f| {
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(3),
                    Constraint::Length(3),
                    Constraint::Length(3),
                    Constraint::Length(3),
                    Constraint::Min(0),
                ])
                .split(f.area());

            render_header(f, chunks[0]);
            render_cpu(f, chunks[1], &metrics.cpu);
            render_memory(f, chunks[2], &metrics.memory);
            render_disk(f, chunks[3], &metrics.disk);
            render_processes(f, chunks[4], &metrics.processes, controller.selected);
        })?;
        Ok(())
    }
}

fn render_header(f: &mut Frame, area: Rect) {
    let text = vec![Line::from(vec![
        Span::styled(
            "System Monitor",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" | "),
        Span::styled("q", Style::default().fg(Color::Yellow)),
        Span::raw(" to quit | "),
        Span::styled("↑↓", Style::default().fg(Color::Yellow)),
        Span::raw(" to navigate"),
    ])];
    let p = Paragraph::new(text).block(Block::default().borders(Borders::ALL));
    f.render_widget(p, area);
}

fn render_cpu(f: &mut Frame, area: Rect, cpu: &crate::models::CpuMetrics) {
    let gauge = Gauge::default()
        .block(Block::default().title("CPU").borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Blue))
        .ratio((cpu.usage_percent / 100.0).min(1.0) as f64)
        .label(format!(
            "{:.1}% | {} cores",
            cpu.usage_percent, cpu.core_count
        ));
    f.render_widget(gauge, area);
}

fn render_memory(f: &mut Frame, area: Rect, mem: &crate::models::MemoryMetrics) {
    let gauge = Gauge::default()
        .block(Block::default().title("Memory").borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Yellow))
        .ratio((mem.percent / 100.0).min(1.0) as f64)
        .label(format!(
            "{} / {} ({:.1}%)",
            utils::format_bytes(mem.used),
            utils::format_bytes(mem.total),
            mem.percent
        ));
    f.render_widget(gauge, area);
}

fn render_disk(f: &mut Frame, area: Rect, disk: &crate::models::DiskMetrics) {
    let gauge = Gauge::default()
        .block(Block::default().title("Disk").borders(Borders::ALL))
        .gauge_style(Style::default().fg(Color::Green))
        .ratio((disk.percent / 100.0).min(1.0) as f64)
        .label(format!(
            "{} / {} ({:.1}%)",
            utils::format_bytes(disk.used),
            utils::format_bytes(disk.total),
            disk.percent
        ));
    f.render_widget(gauge, area);
}

fn render_processes(
    f: &mut Frame,
    area: Rect,
    procs: &[crate::models::ProcessInfo],
    selected: usize,
) {
    let items: Vec<ListItem> = procs
        .iter()
        .enumerate()
        .take(15)
        .map(|(i, p)| {
            let style = if i == selected {
                Style::default().bg(Color::DarkGray).fg(Color::White)
            } else {
                Style::default()
            };
            ListItem::new(format!(
                "{:>6} | {:20} | {:>6.1}% | {}",
                p.pid,
                p.name.chars().take(20).collect::<String>(),
                p.cpu_usage,
                utils::format_bytes(p.memory)
            ))
            .style(style)
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .title("Processes (Top by CPU)")
            .borders(Borders::ALL),
    );
    f.render_widget(list, area);
}
