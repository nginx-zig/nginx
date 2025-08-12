const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nginx",
        .target = target,
        .optimize = optimize,
    });
    setupExe(b, exe);
    {
        const zlib_dep = b.dependency("zlib", .{
            .target = target,
            .optimize = optimize,
        });

        exe.linkLibrary(zlib_dep.artifact("z"));
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run nginx");
    run_step.dependOn(&run_cmd.step);
}

fn readFiles(b: *std.Build) []const []const u8 {
    var files: std.ArrayListUnmanaged([]const u8) = .{};

    const bytes = std.fs.cwd().readFileAlloc(b.allocator, "zobjs/files.txt", 10 * 1024 * 1024) catch @panic("OOM");
    var it = std.mem.splitScalar(u8, bytes, '\n');

    while (it.next()) |v| {
        files.append(b.allocator, v) catch @panic("OOM");
    }

    return files.toOwnedSlice(b.allocator) catch @panic("OOM");
}

fn setupExe(b: *std.Build, exe: *std.Build.Step.Compile) void {
    exe.addCSourceFiles(.{
        .files = readFiles(b),
        .flags = &.{
            "-c",
            "-pipe",
            "-O",
            "-Wall",
            "-Wextra",
            "-Wpointer-arith",
            "-Wconditional-uninitialized",
            "-Wno-unused-parameter",
            "-Wno-deprecated-declarations",
            "-Werror",
            "-g",
        },
    });
    exe.addIncludePath(b.path("src/core"));
    exe.addIncludePath(b.path("src/event"));
    exe.addIncludePath(b.path("src/event/modules"));
    exe.addIncludePath(b.path("src/event/quic"));
    exe.addIncludePath(b.path("src/os/unix"));
    exe.addIncludePath(b.path("zobjs"));

    exe.addIncludePath(b.path("src/http"));
    exe.addIncludePath(b.path("src/http/modules"));
}
