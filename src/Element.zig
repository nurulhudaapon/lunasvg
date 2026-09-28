const std = @import("std");
const c = @import("abi.zig");
const Box = @import("Box.zig");
const Matrix = @import("Matrix.zig");
const Bitmap = @import("Bitmap.zig");

/// Non-owning handle into a Document's SVG element tree.
/// Valid only while the parent Document is alive.
const Element = @This();

_inner: *c.element_t,

pub fn fromC(ptr: ?*c.element_t) ?Element {
    const p = ptr orelse return null;
    if (c.element_is_null(p)) {
        c.element_destroy(p);
        return null;
    }
    return .{ ._inner = p };
}

/// Frees the C wrapper handle (not the underlying SVG node).
pub fn deinit(self: Element) void {
    c.element_destroy(self._inner);
}

pub fn isNull(self: Element) bool {
    return c.element_is_null(self._inner);
}

pub fn hasAttribute(self: Element, name: []const u8) bool {
    return c.element_has_attribute(self._inner, name.ptr, name.len);
}

pub fn getAttribute(self: Element, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var len: usize = 0;
    const ptr = c.element_get_attribute(self._inner, name.ptr, name.len, &len) orelse return error.OutOfMemory;
    return try allocator.dupe(u8, ptr[0..len]);
}

pub fn setAttribute(self: Element, name: []const u8, value: []const u8) void {
    c.element_set_attribute(self._inner, name.ptr, name.len, value.ptr, value.len);
}

pub fn render(self: Element, bitmap: Bitmap, matrix: ?Matrix) void {
    var m_storage: c.matrix_t = undefined;
    const m_ptr: ?*const c.matrix_t = if (matrix) |m| blk: {
        m_storage = m.toC();
        break :blk &m_storage;
    } else null;
    c.element_render(self._inner, bitmap._inner, m_ptr);
}

pub fn renderToBitmap(self: Element, options: Bitmap.RenderOptions) Bitmap.Error!Bitmap {
    return Bitmap.fromC(c.element_render_to_bitmap(
        self._inner,
        options.width,
        options.height,
        options.background_color,
    ));
}

pub fn getLocalMatrix(self: Element) Matrix {
    return Matrix.fromC(c.element_get_local_matrix(self._inner));
}

pub fn getGlobalMatrix(self: Element) Matrix {
    return Matrix.fromC(c.element_get_global_matrix(self._inner));
}

pub fn getLocalBoundingBox(self: Element) Box {
    return Box.fromC(c.element_get_local_bounding_box(self._inner));
}

pub fn getGlobalBoundingBox(self: Element) Box {
    return Box.fromC(c.element_get_global_bounding_box(self._inner));
}

pub fn getBoundingBox(self: Element) Box {
    return Box.fromC(c.element_get_bounding_box(self._inner));
}
