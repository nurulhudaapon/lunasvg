const std = @import("std");
const c = @import("abi.zig");
const Box = @import("Box.zig");
const Matrix = @import("Matrix.zig");
const Bitmap = @import("Bitmap.zig");
const Element = @import("Element.zig");

/// Parsed SVG document.
const Document = @This();

_inner: *c.document_t,

pub const Error = error{
    InvalidSvg,
    OutOfMemory,
};

pub fn loadFromData(svg: []const u8) Error!Document {
    const ptr = c.document_load_from_data(svg.ptr, svg.len) orelse return error.InvalidSvg;
    return .{ ._inner = ptr };
}

pub fn loadFromFile(path: [:0]const u8) Error!Document {
    const ptr = c.document_load_from_file(path.ptr) orelse return error.InvalidSvg;
    return .{ ._inner = ptr };
}

pub fn deinit(self: Document) void {
    c.document_destroy(self._inner);
}

pub fn width(self: Document) f32 {
    return c.document_width(self._inner);
}

pub fn height(self: Document) f32 {
    return c.document_height(self._inner);
}

pub fn boundingBox(self: Document) Box {
    return Box.fromC(c.document_bounding_box(self._inner));
}

pub fn applyStyleSheet(self: Document, css: []const u8) void {
    c.document_apply_stylesheet(self._inner, css.ptr, css.len);
}

pub fn updateLayout(self: Document) void {
    c.document_update_layout(self._inner);
}

pub fn forceLayout(self: Document) void {
    c.document_force_layout(self._inner);
}

pub fn render(self: Document, bitmap: Bitmap, matrix: ?Matrix) void {
    var m_storage: c.matrix_t = undefined;
    const m_ptr: ?*const c.matrix_t = if (matrix) |m| blk: {
        m_storage = m.toC();
        break :blk &m_storage;
    } else null;
    c.document_render(self._inner, bitmap._inner, m_ptr);
}

pub fn renderToBitmap(self: Document, options: Bitmap.RenderOptions) Bitmap.Error!Bitmap {
    return Bitmap.fromC(c.document_render_to_bitmap(
        self._inner,
        options.width,
        options.height,
        options.background_color,
    ));
}

pub fn elementFromPoint(self: Document, x: f32, y: f32) ?Element {
    return Element.fromC(c.document_element_from_point(self._inner, x, y));
}

pub fn getElementById(self: Document, id: []const u8) ?Element {
    return Element.fromC(c.document_get_element_by_id(self._inner, id.ptr, id.len));
}

pub fn documentElement(self: Document) ?Element {
    return Element.fromC(c.document_document_element(self._inner));
}

/// Returns matching elements. Caller owns the slice and each Element handle.
pub fn querySelectorAll(self: Document, allocator: std.mem.Allocator, selectors: []const u8) ![]Element {
    var count: usize = 0;
    const ptrs = c.document_query_selector_all(self._inner, selectors.ptr, selectors.len, &count) orelse {
        return try allocator.alloc(Element, 0);
    };
    defer c.element_list_destroy(ptrs);

    const out = try allocator.alloc(Element, count);
    errdefer {
        for (out[0..]) |el| el.deinit();
        allocator.free(out);
    }

    for (0..count) |i| {
        out[i] = Element.fromC(ptrs[i]) orelse {
            for (ptrs[i + 1 .. count]) |p| {
                if (p) |raw| c.element_destroy(raw);
            }
            for (out[0..i]) |el| el.deinit();
            allocator.free(out);
            return error.OutOfMemory;
        };
    }
    return out;
}

test loadFromData {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
        \\  <rect id="r" x="10" y="10" width="30" height="20" fill="red"/>
        \\  <circle id="c" cx="70" cy="25" r="15" fill="blue"/>
        \\</svg>
    ;

    const doc = try loadFromData(svg);
    defer doc.deinit();

    try std.testing.expectEqual(@as(f32, 100), doc.width());
    try std.testing.expectEqual(@as(f32, 50), doc.height());

    const bbox = doc.boundingBox();
    try std.testing.expect(bbox.w > 0);
    try std.testing.expect(bbox.h > 0);

    const bitmap = try doc.renderToBitmap(.{ .width = 100, .height = 50 });
    defer bitmap.deinit();
    try std.testing.expectEqual(@as(i32, 100), bitmap.width());
    try std.testing.expectEqual(@as(i32, 50), bitmap.height());
    try std.testing.expect(bitmap.data().len > 0);

    const png = try bitmap.writeToPngAlloc(std.testing.allocator);
    defer std.testing.allocator.free(png);
    try std.testing.expect(png.len > 8);
    try std.testing.expectEqualSlices(u8, &.{ 0x89, 0x50, 0x4E, 0x47 }, png[0..4]);
}

test applyStyleSheet {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40">
        \\  <rect class="box" width="40" height="40"/>
        \\</svg>
    ;
    const doc = try loadFromData(svg);
    defer doc.deinit();
    doc.applyStyleSheet(".box { fill: #ff0000; }");
    const bitmap = try doc.renderToBitmap(.{});
    defer bitmap.deinit();
    try std.testing.expect(!bitmap.isNull());
}

test getElementById {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
        \\  <rect id="red-rect" x="10" y="10" width="30" height="20" fill="red"/>
        \\</svg>
    ;
    const doc = try loadFromData(svg);
    defer doc.deinit();

    const el = doc.getElementById("red-rect") orelse return error.TestUnexpectedResult;
    defer el.deinit();

    try std.testing.expect(el.hasAttribute("id"));
    const id = try el.getAttribute(std.testing.allocator, "id");
    defer std.testing.allocator.free(id);
    try std.testing.expectEqualStrings("red-rect", id);

    el.setAttribute("stroke", "black");
    try std.testing.expect(el.hasAttribute("stroke"));

    const local = el.getLocalBoundingBox();
    try std.testing.expect(local.w > 0);
}

test elementFromPoint {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
        \\  <rect id="red-rect" x="10" y="10" width="30" height="20" fill="red"/>
        \\</svg>
    ;
    const doc = try loadFromData(svg);
    defer doc.deinit();

    const hit = doc.elementFromPoint(15, 15) orelse return error.TestUnexpectedResult;
    defer hit.deinit();
    const id = try hit.getAttribute(std.testing.allocator, "id");
    defer std.testing.allocator.free(id);
    try std.testing.expectEqualStrings("red-rect", id);

    try std.testing.expect(doc.elementFromPoint(0, 0) == null);
}

test querySelectorAll {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
        \\  <rect class="shape" id="a" x="0" y="0" width="10" height="10" fill="red"/>
        \\  <rect class="shape" id="b" x="20" y="0" width="10" height="10" fill="blue"/>
        \\</svg>
    ;
    const doc = try loadFromData(svg);
    defer doc.deinit();

    const matches = try doc.querySelectorAll(std.testing.allocator, ".shape");
    defer {
        for (matches) |el| el.deinit();
        std.testing.allocator.free(matches);
    }
    try std.testing.expectEqual(@as(usize, 2), matches.len);
}
