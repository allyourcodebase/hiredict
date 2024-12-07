const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_ssl = b.option(bool, "use-ssl", "Enable TLS support (requires OpenSSL)") orelse false;
    const enable_examples = b.option(bool, "enable-examples", "Build examples") orelse false;
    const enable_tests = b.option(bool, "enable-tests", "Build test suite") orelse false;
    const enable_async_tests = b.option(bool, "enable-async-tests", "Enable asynchronous tests") orelse false;

    const hiredict_dep = b.dependency("hiredict", .{});
    const hiredict_path = hiredict_dep.path(".");

    const lib = b.addStaticLibrary(.{
        .name = "hiredict",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib.addCSourceFiles(.{
        .root = hiredict_path,
        .files = &source_files,
        .flags = &CFLAGS,
    });

    const platform_libs = switch (target.result.os.tag) {
        .windows => &[_][]const u8{ "ws2_32", "crypt32" },
        .freebsd => &[_][]const u8{"m"},
        .solaris => &[_][]const u8{"socket"},
        else => &[_][]const u8{},
    };
    for (platform_libs) |libname| {
        lib.linkSystemLibrary(libname);
    }

    lib.installHeadersDirectory(
        hiredict_path,
        "",
        .{ .include_extensions = &header_files },
    );
    lib.addIncludePath(hiredict_path);
    b.installArtifact(lib);

    const ssl_lib = b.addStaticLibrary(.{
        .name = "hiredict_ssl",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (use_ssl) {
        ssl_lib.addCSourceFile(.{
            .file = hiredict_dep.path("ssl.c"),
            .flags = &CFLAGS,
        });
        ssl_lib.linkSystemLibrary("ssl");
        ssl_lib.linkSystemLibrary("crypto");

        ssl_lib.installHeadersDirectory(hiredict_path, "", .{
            .include_extensions = &.{"hiredict_ssl.h"},
        });
        b.installArtifact(ssl_lib);
    }

    if (enable_examples) {
        const example = try getHiredictExecutable(
            b,
            target,
            optimize,
            hiredict_path,
            hiredict_dep.path("examples/example.c"),
            "hiredict-example",
        );
        example.linkLibrary(lib);

        b.installArtifact(example);

        if (use_ssl) {
            const example_ssl = try getHiredictExecutable(
                b,
                target,
                optimize,
                hiredict_path,
                hiredict_dep.path("examples/example-ssl.c"),
                "hiredict-example-ssl",
            );
            example_ssl.linkLibrary(lib);
            example_ssl.linkLibrary(ssl_lib);

            b.installArtifact(example_ssl);
        }
    }

    if (enable_tests) {
        const test_suite = try getHiredictExecutable(
            b,
            target,
            optimize,
            hiredict_path,
            hiredict_dep.path("test.c"),
            "hiredict-test",
        );

        if (use_ssl) {
            test_suite.linkLibrary(ssl_lib);
            test_suite.defineCMacro("HIREDICT_TEST_SSL", "1");
        }

        if (enable_async_tests) {
            test_suite.linkSystemLibrary("event");
            test_suite.defineCMacro("HIREDICT_TEST_ASYNC", "1");
        }

        test_suite.linkLibrary(lib);

        b.installArtifact(test_suite);
    }
}

fn getHiredictExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    hiredict_path: std.Build.LazyPath,
    sub_path: std.Build.LazyPath,
    name: []const u8,
) !*std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.addCSourceFile(.{
        .file = sub_path,
    });
    exe.addIncludePath(hiredict_path);

    return exe;
}

const CFLAGS = .{"-std=c99"};

const source_files = .{
    "alloc.c",
    "async.c",
    "hiredict.c",
    "net.c",
    "read.c",
    "sds.c",
    "sockcompat.c",
};

const header_files = .{
    "alloc.h",
    "async.h",
    "hiredict.h",
    "net.h",
    "read.h",
    "sds.h",
    "sockcompat.h",
};
