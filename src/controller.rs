#[derive(Debug, Default)]
pub struct Controller {
    pub selected: usize,
}

impl Controller {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn scroll_up(&mut self) {
        self.selected = self.selected.saturating_sub(1);
    }

    pub fn scroll_down(&mut self) {
        self.selected = self.selected.saturating_add(1);
    }

    pub fn page_up(&mut self) {
        self.selected = self.selected.saturating_sub(10);
    }

    pub fn page_down(&mut self) {
        self.selected = self.selected.saturating_add(10);
    }
}
