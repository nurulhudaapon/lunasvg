const std = @import("std");
const lunasvg = @import("lunasvg");

pub fn run(allocator: std.mem.Allocator, io: std.Io) !void {
    _ = io;

    std.log.info(
        \\lunasvg
        \\ - version: {d} ({s})
        \\
        \\
    , .{ lunasvg.version(), lunasvg.versionString() });

    // --- Document + Bitmap --- //
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" width="200" height="120">
        \\  <rect id="bg" width="200" height="120" fill="#1a1a2e"/>
        \\  <circle id="sun" class="orb" cx="150" cy="40" r="28" fill="#f4a261"/>
        \\  <rect id="ground" class="land" y="80" width="200" height="40" fill="#2a9d8f"/>
        \\  <rect id="box" x="20" y="30" width="60" height="40" fill="#e76f51"/>
        \\</svg>
    ;

    const doc = try lunasvg.Document.loadFromData(svg);
    defer doc.deinit();

    const bbox = doc.boundingBox();
    std.log.info(
        \\Document
        \\ - width/height: {d}/{d}
        \\ - boundingBox: x={d} y={d} w={d} h={d}
        \\
        \\
    , .{
        doc.width(),
        doc.height(),
        bbox.x,
        bbox.y,
        bbox.w,
        bbox.h,
    });

    var bitmap = try doc.renderToBitmap(.{ .width = 200, .height = 120 });
    defer bitmap.deinit();
    std.log.info(
        \\Bitmap
        \\ - size: {d}x{d}
        \\ - stride: {d}
        \\ - pixels: {d} bytes
        \\
        \\
    , .{
        bitmap.width(),
        bitmap.height(),
        bitmap.stride(),
        bitmap.data().len,
    });

    const png = try bitmap.writeToPngAlloc(allocator);
    defer allocator.free(png);
    std.log.info(
        \\PNG
        \\ - encoded size: {d} bytes
        \\ - signature: {x}
        \\
        \\
    , .{ png.len, png[0..4] });

    // --- Dynamic styling --- //
    doc.applyStyleSheet(
        \\.orb { fill: #ffd166; }
        \\.land { fill: #06d6a0; }
    );
    var styled = try doc.renderToBitmap(.{ .width = 200, .height = 120 });
    defer styled.deinit();
    const styled_png = try styled.writeToPngAlloc(allocator);
    defer allocator.free(styled_png);
    std.log.info(
        \\Styled Bitmap
        \\ - PNG size after stylesheet: {d} bytes
        \\
        \\
    , .{styled_png.len});

    // --- Element lookup + hit testing --- //
    if (doc.getElementById("box")) |el| {
        defer el.deinit();
        const id = try el.getAttribute(allocator, "id");
        defer allocator.free(id);
        const local = el.getLocalBoundingBox();
        std.log.info(
            \\Element#box
            \\ - id: {s}
            \\ - local bbox: x={d} y={d} w={d} h={d}
            \\
            \\
        , .{ id, local.x, local.y, local.w, local.h });

        el.setAttribute("stroke", "white");
        el.setAttribute("stroke-width", "3");
    }

    if (doc.elementFromPoint(150, 40)) |hit| {
        defer hit.deinit();
        const id = try hit.getAttribute(allocator, "id");
        defer allocator.free(id);
        std.log.info(
            \\Hit test (150, 40)
            \\ - element: {s}
            \\
            \\
        , .{id});
    } else {
        std.log.info("Hit test (150, 40): no element\n\n", .{});
    }

    // --- Matrix --- //
    const matrix = lunasvg.Matrix.translated(10, 20).scale(1.5, 1.5).rotate(15, 0, 0);
    std.log.info(
        \\Matrix
        \\ - a={d} b={d} c={d} d={d} e={d} f={d}
        \\
        \\
    , .{ matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f });

    // --- Convenience helper --- //
    const quick_png = try lunasvg.svgToPngAlloc(allocator, svg, 64, 64, 0x00000000);
    defer allocator.free(quick_png);
    std.log.info(
        \\svgToPngAlloc
        \\ - 64x64 PNG size: {d} bytes
        \\
        \\
    , .{quick_png.len});
}
