const std = @import("std");
const c = @import("abi.zig");

/// Bitmap pixel format is ARGB32 premultiplied unless `convertToRGBA` was called.
const Bitmap = @This();

_inner: *c.bitmap_t,

pub const Error = error{
    NullBitmap,
    PngEncodeFailed,
    OutOfMemory,
};

pub fn init(width_val: i32, height_val: i32) Error!Bitmap {
    const ptr = c.bitmap_create(width_val, height_val) orelse return error.NullBitmap;
    return .{ ._inner = ptr };
}

pub fn initForData(pixels: []u8, width_val: i32, height_val: i32, stride_val: i32) Error!Bitmap {
    const ptr = c.bitmap_create_for_data(pixels.ptr, width_val, height_val, stride_val) orelse return error.NullBitmap;
    return .{ ._inner = ptr };
}

pub fn fromC(ptr: ?*c.bitmap_t) Error!Bitmap {
    return .{ ._inner = ptr orelse return error.NullBitmap };
}

pub fn deinit(self: Bitmap) void {
    c.bitmap_destroy(self._inner);
}

pub fn data(self: Bitmap) []u8 {
    const ptr = c.bitmap_data(self._inner) orelse return &.{};
    const len: usize = @intCast(c.bitmap_stride(self._inner) * c.bitmap_height(self._inner));
    return ptr[0..len];
}

pub fn width(self: Bitmap) i32 {
    return c.bitmap_width(self._inner);
}

pub fn height(self: Bitmap) i32 {
    return c.bitmap_height(self._inner);
}

pub fn stride(self: Bitmap) i32 {
    return c.bitmap_stride(self._inner);
}

pub fn isNull(self: Bitmap) bool {
    return c.bitmap_is_null(self._inner);
}

pub fn clear(self: Bitmap, color: u32) void {
    c.bitmap_clear(self._inner, color);
}

pub fn convertToRGBA(self: Bitmap) void {
    c.bitmap_convert_to_rgba(self._inner);
}

pub fn writeToPngFile(self: Bitmap, path: [:0]const u8) Error!void {
    if (!c.bitmap_write_to_png_file(self._inner, path.ptr)) return error.PngEncodeFailed;
}

pub fn writeToPngAlloc(self: Bitmap, allocator: std.mem.Allocator) Error![]u8 {
    var output = std.Io.Writer.Allocating.init(allocator);
    errdefer output.deinit();

    var ctx = WriteContext{ .writer = &output.writer };
    const ok = c.bitmap_write_to_png(self._inner, writePngChunk, &ctx);
    if (ctx.err) |err| return err;
    if (!ok) return error.PngEncodeFailed;
    return output.toOwnedSlice() catch error.OutOfMemory;
}

const WriteContext = struct {
    writer: *std.Io.Writer,
    err: ?Error = null,
};

fn writePngChunk(closure: ?*anyopaque, data_ptr: ?*anyopaque, size: c_int) callconv(.c) void {
    if (size <= 0) return;
    const ctx: *WriteContext = @ptrCast(@alignCast(closure.?));
    if (ctx.err != null) return;
    const bytes: [*]const u8 = @ptrCast(data_ptr.?);
    ctx.writer.writeAll(bytes[0..@intCast(size)]) catch {
        ctx.err = error.OutOfMemory;
    };
}

/// Optional render options shared by Document/Element.
pub const RenderOptions = struct {
    width: i32 = -1,
    height: i32 = -1,
    background_color: u32 = 0x00000000,
};
