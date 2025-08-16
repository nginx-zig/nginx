const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nginx",
        .target = target,
        .optimize = optimize,
    });

    const hub = Mod.Hub.new(b, exe);
    hub.setup(.{});

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run nginx");
    run_step.dependOn(&run_cmd.step);
}

const Mod = struct {
    name: []const u8,
    files: []const []const u8,
    flags: ?[]const []const u8 = null,
    incs: ?[]const []const u8 = null,
    h: *Hub,

    const Hub = struct {
        b: *std.Build,
        exe: *std.Build.Step.Compile,

        const Opt = struct {};

        fn new(b: *std.Build, exe: *std.Build.Step.Compile) *Hub {
            const h = b.allocator.create(Hub) catch @panic("OOM");
            h.* = .{
                .b = b,
                .exe = exe,
            };
            return h;
        }

        fn setup(h: *Hub, opt: Opt) void {
            _ = opt;
            const b = h.b;
            const exe = h.exe;
            const target = exe.root_module.resolved_target.?;
            const optimize = exe.root_module.optimize.?;

            const core_mod: Mod = .{
                .name = "core",
                .files = h.readFiles("zobjs/files.txt"),
                .h = h,
            };

            const event_mod: Mod = .{
                .name = "event",
                .files = h.readFiles("zobjs/files-event.txt"),
                .incs = &.{
                    b.pathFromRoot("src/event/modules"),
                    b.pathFromRoot("src/event/quic"),
                },
                .h = h,
            };

            const http_mod: Mod = .{
                .name = "http",
                .files = h.readFiles("zobjs/files-http.txt"),
                .incs = &.{
                    b.pathFromRoot("src/http"),
                    b.pathFromRoot("src/http/modules"),
                },
                .h = h,
            };

            core_mod.addTo(exe);
            event_mod.addTo(exe);
            http_mod.addTo(exe);

            exe.addIncludePath(b.path("zobjs"));
            exe.addIncludePath(b.path("src/core"));
            exe.addIncludePath(b.path("src/event"));

            exe.addIncludePath(b.path("src/os/unix"));

            {
                const zlib_dep = b.dependency("zlib", .{
                    .target = target,
                    .optimize = optimize,
                });

                exe.linkLibrary(zlib_dep.artifact("z"));
            }
        }

        fn readFiles(h: *Hub, path: []const u8) []const []const u8 {
            const bytes = std.fs.cwd().readFileAlloc(h.b.allocator, path, 10 * 1024 * 1024) catch @panic("OOM");

            return h.parseLines(bytes);
        }
        fn parseLines(h: *Hub, bytes: []const u8) []const []const u8 {
            var files: std.ArrayListUnmanaged([]const u8) = .{};
            var it = std.mem.splitScalar(u8, bytes, '\n');

            while (it.next()) |v| {
                const v2 = std.mem.trim(u8, v, " \t");
                if (v2.len == 0 or std.mem.startsWith(u8, v2, "#")) {
                    continue;
                }

                files.append(h.b.allocator, v2) catch @panic("OOM");
            }

            return files.toOwnedSlice(h.b.allocator) catch @panic("OOM");
        }
    };

    fn addTo(m: *const Mod, exe: *std.Build.Step.Compile) void {
        var flags = std.ArrayList([]const u8).init(m.h.b.allocator);
        flags.appendSlice(&.{
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
        }) catch @panic("OOM");

        if (m.flags) |mflags| {
            flags.appendSlice(mflags) catch @panic("OOM");
        }
        if (m.incs) |mincs| {
            flags.ensureUnusedCapacity(mincs.len) catch @panic("OOM");
            for (mincs) |inc| {
                flags.appendAssumeCapacity(m.h.b.fmt("-I{s}", .{inc}));
            }
        }

        exe.addCSourceFiles(.{
            .files = m.files,
            .flags = flags.items,
        });
    }
};
