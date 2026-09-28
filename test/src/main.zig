const std = @import("std");
const program = @import("root.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    try program.run(allocator, init.io);
}
