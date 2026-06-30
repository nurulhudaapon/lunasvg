const std = @import("std");

pub const Error = error{
    InvalidSvg,
    PngEncodeFailed,
    OutOfMemory,
};

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
    const ok = lunasvg_svg_to_png(
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

extern fn lunasvg_svg_to_png(
    svg_data: [*]const u8,
    svg_len: usize,
    width: c_int,
    height: c_int,
    background_color: u32,
    write_func: *const fn (?*anyopaque, ?*anyopaque, c_int) callconv(.c) void,
    closure: ?*anyopaque,
) bool;
