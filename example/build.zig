const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const hiredict = b.dependency("hiredict", .{
        .target = target,
        .optimize = optimize,
        .@"use-ssl" = true,
    });

    const exe = b.addExecutable(.{
        .name = "chiredict",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.addCSourceFile(.{
        .file = b.path("main.c"),
    });
    exe.linkLibrary(hiredict.artifact("hiredict"));
    exe.linkLibrary(hiredict.artifact("hiredict_ssl"));

    b.installArtifact(exe);
}
