use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use std::time::Duration;
use tokio::time::interval;

use system_monitor::{collector::Collector, config::Settings, controller::Controller, ui::Ui};

#[tokio::main]  // FIXED: was #[tokio:main]
async fn main() -> Result<()> {
    let settings = Settings::load().unwrap_or_default();

    enable_raw_mode()?;
    let mut stdout = std::io::stdout();
    execute!(stdout, EnterAlternateScreen)?;

    let collector = Collector::new();
    let mut ui = Ui::new()?;
    let mut controller = Controller::new();

    let result = run_loop(&collector, &mut ui, &mut controller, &settings).await;

    disable_raw_mode()?;
    execute!(stdout, LeaveAlternateScreen)?;

    result
}

async fn run_loop(
    collector: &Collector,
    ui: &mut Ui,
    controller: &mut Controller,
    settings: &Settings,
) -> Result<()> {
    let mut tick = interval(Duration::from_millis(settings.update_ms));

    loop {
        tokio::select! {
            _ = tick.tick() => {
                let metrics = collector.collect_all().await?;
                ui.render(&metrics, controller)?;
            }

            _ = tokio::time::sleep(Duration::from_millis(10)) => {
                if event::poll(Duration::from_millis(0))? {
                    if let Event::Key(key) = event::read()? {
                        if key.kind == KeyEventKind::Press {
                            match key.code {
                                KeyCode::Char('q') | KeyCode::Esc => return Ok(()),  // FIXED: was ok(())
                                KeyCode::Up => controller.scroll_up(),
                                KeyCode::Down => controller.scroll_down(),
                                KeyCode::PageUp => controller.page_up(),
                                KeyCode::PageDown => controller.page_down(),
                                _ => {}
                            }
                        }
                    }
                }
            }
        }
    }
}
