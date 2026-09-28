const std = @import("std");
const c = @import("abi.zig");

pub const Box = @import("Box.zig");
pub const Matrix = @import("Matrix.zig");
pub const Bitmap = @import("Bitmap.zig");
pub const Element = @import("Element.zig");
pub const Document = @import("Document.zig");

pub const Error = error{
    InvalidSvg,
    PngEncodeFailed,
    OutOfMemory,
    NullBitmap,
};

/// Library version encoded as a single integer.
pub fn version() i32 {
    return c.version();
}

/// Library version string in "X.Y.Z" format.
pub fn versionString() [:0]const u8 {
    return std.mem.span(c.version_string());
}

/// Add a font face from a file path.
pub fn addFontFaceFromFile(family: [:0]const u8, bold: bool, italic: bool, filename: [:0]const u8) bool {
    return c.add_font_face_from_file(family.ptr, bold, italic, filename.ptr);
}

/// Add a font face from an in-memory buffer. The buffer must outlive the cache
/// unless a destroy callback is provided via the C API.
pub fn addFontFaceFromData(family: [:0]const u8, bold: bool, italic: bool, data: []const u8) bool {
    return c.add_font_face_from_data(family.ptr, bold, italic, data.ptr, data.len, null, null);
}

/// Convenience: load SVG bytes and encode a PNG into an allocated buffer.
pub fn svgToPngAlloc(
    allocator: std.mem.Allocator,
    svg: []const u8,
    width: i32,
    height: i32,
    background_color: u32,
) Error![]u8 {
    var output = std.Io.Writer.Allocating.init(allocator);
    errdefer output.deinit();

    var ctx = WriteContext{ .writer = &output.writer };
    const ok = c.svg_to_png(
        svg.ptr,
        svg.len,
        width,
        height,
        background_color,
        writePngChunk,
        &ctx,
    );

    if (ctx.err) |err| return err;
    if (!ok) return error.InvalidSvg;

    return output.toOwnedSlice() catch error.OutOfMemory;
}

const WriteContext = struct {
    writer: *std.Io.Writer,
    err: ?Error = null,
};

fn writePngChunk(closure: ?*anyopaque, data: ?*anyopaque, size: c_int) callconv(.c) void {
    if (size <= 0) return;

    const ctx: *WriteContext = @ptrCast(@alignCast(closure.?));
    if (ctx.err != null) return;

    const bytes: [*]const u8 = @ptrCast(data.?);
    ctx.writer.writeAll(bytes[0..@intCast(size)]) catch {
        ctx.err = error.OutOfMemory;
    };
}

test {
    _ = @import("Document.zig");
    _ = @import("Bitmap.zig");
    _ = @import("Element.zig");
    _ = @import("Matrix.zig");
    _ = @import("Box.zig");
}

test version {
    try std.testing.expect(version() > 0);
    try std.testing.expect(versionString().len > 0);
}

test Matrix {
    const m = Matrix.translated(10, 20).scale(2, 2);
    try std.testing.expectEqual(@as(f32, 2), m.a);
    try std.testing.expectEqual(@as(f32, 2), m.d);
    try std.testing.expectEqual(@as(f32, 10), m.e);
    try std.testing.expectEqual(@as(f32, 20), m.f);

    const inv = m.inverse();
    const identityish = m.multiply(inv);
    try std.testing.expect(@abs(identityish.a - 1) < 0.001);
    try std.testing.expect(@abs(identityish.d - 1) < 0.001);
}

test Box {
    const box = Box.init(1, 2, 3, 4);
    const moved = box.transformed(Matrix.translated(10, 20));
    try std.testing.expectEqual(@as(f32, 11), moved.x);
    try std.testing.expectEqual(@as(f32, 22), moved.y);
    try std.testing.expectEqual(@as(f32, 3), moved.w);
    try std.testing.expectEqual(@as(f32, 4), moved.h);
}

test svgToPngAlloc {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
        \\  <rect width="16" height="16" fill="green"/>
        \\</svg>
    ;
    const png = try svgToPngAlloc(std.testing.allocator, svg, 16, 16, 0x00000000);
    defer std.testing.allocator.free(png);
    try std.testing.expectEqualSlices(u8, &.{ 0x89, 0x50, 0x4E, 0x47 }, png[0..4]);
}
