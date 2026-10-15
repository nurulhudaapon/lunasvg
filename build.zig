const std = @import("std");

const vendor_root = "vendor";

pub fn build(b: *std.Build) !void {
    // Internal flag used by `zig build vendor` so the lazy upstream dep is only
    // fetched for that step, not for ordinary builds.
    const do_vendor = b.option(bool, "do-vendor", "Internal: sync upstream into vendor/") orelse false;
    if (do_vendor) {
        syncVendor(b);
        return;
    }

    addVendorStep(b);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lunasvg_root = b.path(vendor_root);
    const is_wasi = target.result.cpu.arch.isWasm() and target.result.os.tag == .wasi;

    const static_lib = addLunasvg(b, target, optimize, .static, lunasvg_root);
    if (!is_wasi) {
        _ = addLunasvg(b, target, optimize, .shared, lunasvg_root);
    }

    const translated = b.addTranslateC(.{
        .root_source_file = b.path("src/shims/lunasvg_c.h"),
        .target = target,
        .optimize = optimize,
    });
    translated.addIncludePath(b.path("src"));
    const c_mod = translated.createModule();

    const lunasvg_mod = b.addModule("lunasvg", .{
        .root_source_file = b.path("src/lunasvg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    lunasvg_mod.addImport("c", c_mod);
    lunasvg_mod.linkLibrary(static_lib);

    // --- Step: run --- //
    {
        const run_step = b.step("run", "Run the example project");
        const run_cmd = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "run",
            b.fmt("-Dtarget={s}", .{try target.result.zigTriple(b.allocator)}),
        });
        run_cmd.setCwd(b.path("test"));
        run_cmd.addPassthruArgs();
        run_step.dependOn(&run_cmd.step);
    }

    // --- Step: test --- //
    {
        const test_mod = b.createModule(.{
            .root_source_file = b.path("src/lunasvg.zig"),
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });
        test_mod.addImport("c", c_mod);
        test_mod.linkLibrary(static_lib);
        const tests = b.addTest(.{
            .root_module = test_mod,
            .test_runner = .{
                .path = b.path("test/runner.zig"),
                .mode = .simple,
            },
        });
        const run_tests = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run library tests");
        test_step.dependOn(&run_tests.step);
    }

    // --- Step: svg2png --- //
    if (!is_wasi) {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });
        const exe = b.addExecutable(.{
            .name = "svg2png",
            .root_module = mod,
        });
        mod.addIncludePath(lunasvg_root.path(b, "include"));
        mod.addCSourceFiles(.{
            .root = lunasvg_root,
            .files = &.{"examples/svg2png.cpp"},
            .flags = &.{"-std=c++17"},
        });

        mod.linkLibrary(static_lib);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.addPassthruArgs();
        const run_step = b.step("svg2png", "Run svg2png");
        run_step.dependOn(&run_cmd.step);
    }
}

/// Public step: `zig build vendor` shells into a -Ddo-vendor build so the lazy
/// upstream package is fetched only for vendoring. Uses `-p .` so installDirectory
/// writes into `./vendor` instead of `zig-out/vendor`.
fn addVendorStep(b: *std.Build) void {
    const vendor_step = b.step("vendor", "Sync and patch upstream lunasvg into vendor/");
    const cmd = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "build",
        "-Ddo-vendor=true",
        "-p",
        ".",
    });
    cmd.setCwd(b.path("."));
    cmd.has_side_effects = true;
    vendor_step.dependOn(&cmd.step);
}

/// Fetch lazy upstream, installDirectory into vendor/, then apply .patch files in place.
fn syncVendor(b: *std.Build) void {
    const dep = b.lazyDependency("lunasvg", .{}) orelse return;

    const install = b.addInstallDirectory(.{
        .source_dir = dep.path("."),
        .install_dir = .prefix,
        .install_subdir = vendor_root,
    });
    b.getInstallStep().dependOn(&install.step);

    // Apply patches after install (requires `patch`; only needed for this one-off vendor step).
    var prev: *std.Build.Step = &install.step;
    for (vendor_patches) |patch_file| {
        const patch = b.addSystemCommand(&.{ "patch", "-p1", "--forward", "--batch", "-i" });
        patch.setName(b.fmt("patch {s}", .{patch_file}));
        patch.addFileArg(b.path(patch_file));
        patch.setCwd(b.path(vendor_root));
        patch.step.dependOn(prev);
        b.getInstallStep().dependOn(&patch.step);
        prev = &patch.step;
    }
}

const vendor_patches = [_][]const u8{
    "patches/lunasvg.cpp.patch",
    "patches/plutovg-ft-raster.c.patch",
};

pub fn addLunasvg(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    kind: enum { static, shared },
    lunasvg_root: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const is_wasi = target.result.cpu.arch.isWasm() and target.result.os.tag == .wasi;
    const cpp_flags = if (is_wasi)
        &[_][]const u8{ "-std=c++17", "-fno-exceptions" }
    else
        &[_][]const u8{"-std=c++17"};
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const lib = switch (kind) {
        .static => b.addLibrary(.{
            .name = "lunasvg-static",
            .root_module = mod,
            .linkage = .static,
        }),
        .shared => b.addLibrary(.{
            .name = "lunasvg",
            .root_module = mod,
            .linkage = .dynamic,
        }),
    };

    mod.addIncludePath(lunasvg_root.path(b, "include"));
    mod.addIncludePath(lunasvg_root.path(b, "source"));
    mod.addIncludePath(lunasvg_root.path(b, "plutovg/include"));
    mod.addIncludePath(lunasvg_root.path(b, "plutovg/source"));
    mod.addIncludePath(b.path("src"));
    mod.addCMacro("PLUTOVG_BUILD", "");
    mod.addCMacro("PATH_MAX", "4096");
    if (is_wasi) {
        mod.addCMacro("LUNASVG_DISABLE_FILESYSTEM", "");
        mod.addCMacro("LUNASVG_DISABLE_LOAD_SYSTEM_FONTS", "");
        mod.addCMacro("LUNASVG_DISABLE_EXTERNAL_RESOURCES", "");
        mod.addCMacro("PLUTOVG_DISABLE_FONT_FACE_CACHE_LOAD", "");
    }

    switch (kind) {
        .static => {
            mod.addCMacro("LUNASVG_BUILD", "");
            mod.addCMacro("LUNASVG_BUILD_STATIC", "");
            mod.addCMacro("PLUTOVG_BUILD_STATIC", "");
            lib.installHeader(
                lunasvg_root.path(b, "include/lunasvg.h"),
                "lunasvg-unconfigured.h",
            );
            const w = b.addWriteFiles();
            lib.installHeader(
                w.add("lunasvg.h", ("#define LUNASVG_BUILD_STATIC\n" ++
                    "#include \"lunasvg-unconfigured.h\"\n")),
                "lunasvg.h",
            );
        },
        .shared => {
            mod.addCMacro("LUNASVG_BUILD", "");
        },
    }

    mod.addCSourceFiles(.{
        .root = lunasvg_root,
        .files = &lunasvg_cpp_files,
        .flags = cpp_flags,
    });
    mod.addCSourceFiles(.{
        .root = lunasvg_root,
        .files = &plutovg_c_files,
        .flags = &.{"-std=c11"},
    });
    mod.addCSourceFiles(.{
        .root = b.path("."),
        .files = &.{"src/shims/lunasvg.cpp"},
        .flags = cpp_flags,
    });
    b.installArtifact(lib);
    return lib;
}

const lunasvg_cpp_files = [_][]const u8{
    "source/lunasvg.cpp",
    "source/graphics.cpp",
    "source/svgelement.cpp",
    "source/svggeometryelement.cpp",
    "source/svglayoutstate.cpp",
    "source/svgpaintelement.cpp",
    "source/svgparser.cpp",
    "source/svgproperty.cpp",
    "source/svgrenderstate.cpp",
    "source/svgtextelement.cpp",
};

const plutovg_c_files = [_][]const u8{
    "plutovg/source/plutovg-blend.c",
    "plutovg/source/plutovg-canvas.c",
    "plutovg/source/plutovg-font.c",
    "plutovg/source/plutovg-matrix.c",
    "plutovg/source/plutovg-paint.c",
    "plutovg/source/plutovg-path.c",
    "plutovg/source/plutovg-rasterize.c",
    "plutovg/source/plutovg-surface.c",
    "plutovg/source/plutovg-ft-math.c",
    "plutovg/source/plutovg-ft-raster.c",
    "plutovg/source/plutovg-ft-stroker.c",
};
