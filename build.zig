const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lunasvg_dep = b.dependency("lunasvg", .{});
    const lunasvg_root = lunasvg_dep.path(".");
    const patched = applyWasiPatch(b, lunasvg_dep);
    const is_wasi = target.result.cpu.arch.isWasm() and target.result.os.tag == .wasi;

    const static_lib = addLunasvg(b, target, optimize, .static, patched);
    if (!is_wasi) {
        _ = addLunasvg(b, target, optimize, .shared, patched);
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
        mod.addIncludePath(lunasvg_dep.path("include"));
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

fn applyWasiPatch(b: *std.Build, lunasvg_dep: *std.Build.Dependency) std.Build.LazyPath {
    const patched = b.addWriteFiles();
    _ = patched.addCopyFile(
        patchFile(b, lunasvg_dep.path("source/lunasvg.cpp"), b.path("patches/lunasvg.cpp.patch"), "lunasvg.cpp"),
        "source/lunasvg.cpp",
    );
    _ = patched.addCopyFile(
        patchFile(
            b,
            lunasvg_dep.path("plutovg/source/plutovg-ft-raster.c"),
            b.path("patches/plutovg-ft-raster.c.patch"),
            "plutovg-ft-raster.c",
        ),
        "plutovg/source/plutovg-ft-raster.c",
    );
    return patched.getDirectory();
}

fn patchFile(
    b: *std.Build,
    input: std.Build.LazyPath,
    patch_path: std.Build.LazyPath,
    out_name: []const u8,
) std.Build.LazyPath {
    const patch = b.addSystemCommand(&.{ "patch", "-p1", "-s", "--batch" });
    patch.setName(b.fmt("patch {s}", .{out_name}));
    patch.rename_step_with_output_arg = false;
    patch.addPrefixedFileArg("-i", patch_path);
    patch.addArg("-o");
    const out = patch.addOutputFileArg(out_name);
    patch.addFileArg(input);
    return out;
}

pub fn addLunasvg(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    kind: enum { static, shared },
    patched: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const lunasvg_dep = b.dependency("lunasvg", .{});
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

    mod.addIncludePath(lunasvg_dep.path("include"));
    mod.addIncludePath(lunasvg_dep.path("source"));
    mod.addIncludePath(lunasvg_dep.path("plutovg/include"));
    mod.addIncludePath(lunasvg_dep.path("plutovg/source"));
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
                lunasvg_dep.path("include/lunasvg.h"),
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

    // Upstream sources except the two files we compile from the patched tree.
    mod.addCSourceFiles(.{
        .root = lunasvg_dep.path("."),
        .files = &lunasvg_cpp_files_unpatched,
        .flags = cpp_flags,
    });
    mod.addCSourceFiles(.{
        .root = lunasvg_dep.path("."),
        .files = &plutovg_c_files_unpatched,
        .flags = &.{"-std=c11"},
    });
    mod.addCSourceFile(.{
        .file = patched.path(b, "source/lunasvg.cpp"),
        .flags = cpp_flags,
    });
    mod.addCSourceFile(.{
        .file = patched.path(b, "plutovg/source/plutovg-ft-raster.c"),
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

const lunasvg_cpp_files_unpatched = [_][]const u8{
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

const plutovg_c_files_unpatched = [_][]const u8{
    "plutovg/source/plutovg-blend.c",
    "plutovg/source/plutovg-canvas.c",
    "plutovg/source/plutovg-font.c",
    "plutovg/source/plutovg-matrix.c",
    "plutovg/source/plutovg-paint.c",
    "plutovg/source/plutovg-path.c",
    "plutovg/source/plutovg-rasterize.c",
    "plutovg/source/plutovg-surface.c",
    "plutovg/source/plutovg-ft-math.c",
    "plutovg/source/plutovg-ft-stroker.c",
};
