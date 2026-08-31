//! Zig's `+|` / `-|` are built-in saturating-arithmetic operators, so this
//! is a near-literal translation of `saturating_add` / `saturating_sub`.
pub const Controller = struct {
    selected: usize = 0,

    pub fn scrollUp(self: *Controller) void {
        self.selected -|= 1;
    }

    pub fn scrollDown(self: *Controller) void {
        self.selected +|= 1;
    }

    pub fn pageUp(self: *Controller) void {
        self.selected -|= 10;
    }

    pub fn pageDown(self: *Controller) void {
        self.selected +|= 10;
    }
};
