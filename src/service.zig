const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;

const Release = @import("release.zig").Release;

pub fn add(allocator: Allocator, rel: Release) !void {
    if (mem.eql(u8, rel.distribution, "none"))
        return error.DistributionError
    else
        try erlsrv(allocator, "add", rel);
}
pub fn remove(allocator: Allocator, rel: Release) !void {
    try erlsrv(allocator, "remove", rel);
}
pub fn start(allocator: Allocator, rel: Release) !void {
    try erlsrv(allocator, "start", rel);
}
pub fn stop(allocator: Allocator, rel: Release) !void {
    try erlsrv(allocator, "stop", rel);
}
pub fn list(allocator: Allocator, rel: Release) !void {
    try erlsrv(allocator, "list", rel);
}
pub fn help(allocator: Allocator, rel: Release) !void {
    try erlsrv(allocator, "help", rel);
}

fn erlsrv(allocator: Allocator, command: []const u8, rel: Release) !void {
    const erlsrv_path = try erlsrvPath(allocator, rel);
    const argv = blk: {
        if (mem.eql(u8, command, "add")) {
            break :blk ([_][]const u8{
                erlsrv_path,
                "add",
                try fmt.allocPrint(allocator, "{s}_{s}", .{ rel.name, rel.name }),
                try fmt.allocPrint(allocator, "-{s}", .{rel.distribution}),
                rel.node,
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_ROOT={s}", .{rel.root}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_NAME={s}", .{rel.name}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_VSN={s}", .{rel.vsn}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_MODE={s}", .{rel.mode}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_COOKIE={s}", .{rel.cookie}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_NODE={s}", .{rel.node}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_VM_ARGS={s}", .{rel.vm_args}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_TMP={s}", .{rel.tmp}),
                "-env",
                try fmt.allocPrint(allocator, "RELEASE_SYS_CONFIG={s}", .{rel.sys_config}),
                "-args",
                try fmt.allocPrint(
                    allocator,
                    "-setcookie {s} -config {s} -mode {s} -boot {s}\\start -boot_var RELEASE_LIB {s}\\lib -args_file {s}\\vm.args",
                    .{
                        rel.cookie,
                        rel.sys_config,
                        rel.mode,
                        rel.vsn_dir,
                        rel.root,
                        rel.vsn_dir,
                    },
                ),
            })[0..];
        } else if (mem.eql(u8, command, "list") or mem.eql(u8, command, "help")) {
            break :blk ([_][]const u8{ erlsrv_path, command })[0..];
        } else {
            break :blk ([_][]const u8{
                erlsrv_path,
                command,
                try fmt.allocPrint(allocator, "{s}_{s}", .{ rel.name, rel.name }),
            })[0..];
        }
    };

    const child_proc = try std.ChildProcess.init(argv, allocator);
    child_proc.stdin_behavior = .Inherit;
    child_proc.stdout_behavior = .Inherit;
    _ = try child_proc.spawnAndWait();
}

fn erlsrvPath(allocator: Allocator, rel: Release) ![]const u8 {
    const erts_dir = try fmt.allocPrint(allocator, "erts-{s}", .{rel.erts_vsn});
    const erts_path = try fs.path.resolve(allocator, &[_][]const u8{ rel.root, erts_dir });
    if (pathExists(erts_path)) return try fs.path.join(allocator, &[_][]const u8{ erts_path, "bin", "erlsrv.exe" });
    return "erlsrv.exe";
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}
