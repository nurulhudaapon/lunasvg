const abi = @import("abi.zig");
const Matrix = @import("Matrix.zig");

/// Axis-aligned bounding box.
x: f32 = 0,
y: f32 = 0,
w: f32 = 0,
h: f32 = 0,

const Box = @This();

pub fn init(x_val: f32, y_val: f32, w_val: f32, h_val: f32) Box {
    return .{ .x = x_val, .y = y_val, .w = w_val, .h = h_val };
}

pub fn fromC(box: abi.box_t) Box {
    return .{ .x = box.x, .y = box.y, .w = box.w, .h = box.h };
}

pub fn toC(self: Box) abi.box_t {
    return .{ .x = self.x, .y = self.y, .w = self.w, .h = self.h };
}

pub fn transformed(self: Box, matrix: Matrix) Box {
    return fromC(abi.box_transformed(self.toC(), matrix.toC()));
}
