const std = @import("std");
const s = std.fmt.allocPrint;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;

const Release = @import("release.zig").Release;

pub fn add(a: Allocator, rel: Release) !void {
    if (mem.eql(u8, rel.distribution, "none"))
        return error.DistributionError
    else
        try erlsrv(a, "add", rel);
}
pub fn remove(a: Allocator, rel: Release) !void {
    try erlsrv(a, "remove", rel);
}
pub fn start(a: Allocator, rel: Release) !void {
    try erlsrv(a, "start", rel);
}
pub fn stop(a: Allocator, rel: Release) !void {
    try erlsrv(a, "stop", rel);
}
pub fn list(a: Allocator, rel: Release) !void {
    try erlsrv(a, "list", rel);
}
pub fn help(a: Allocator, rel: Release) !void {
    try erlsrv(a, "help", rel);
}

const ErlSrvCommand = enum {
    add,
    remove,
    start,
    stop,
    enable,
    disable,
    list,
    help,
};

fn erlsrvArgs(a: Allocator, command: []const u8, erlsrv_path: []const u8, rel: Release) ![][]const u8 {
    return switch (command) {
        .add => [_][]const u8{
            erlsrv_path,
            "add",
            try s(a, "{s}_{s}", .{ rel.name, rel.name }),
            try s(a, "-{s}", .{rel.distribution}),
            rel.node,
            "-env",
            try s(a, "RELEASE_ROOT={s}", .{rel.root}),
            "-env",
            try s(a, "RELEASE_NAME={s}", .{rel.name}),
            "-env",
            try s(a, "RELEASE_VSN={s}", .{rel.vsn}),
            "-env",
            try s(a, "RELEASE_MODE={s}", .{rel.mode}),
            "-env",
            try s(a, "RELEASE_COOKIE={s}", .{rel.cookie}),
            "-env",
            try s(a, "RELEASE_NODE={s}", .{rel.node}),
            "-env",
            try s(a, "RELEASE_VM_ARGS={s}", .{rel.vm_args}),
            "-env",
            try s(a, "RELEASE_TMP={s}", .{rel.tmp}),
            "-env",
            try s(a, "RELEASE_SYS_CONFIG={s}", .{rel.sys_config}),
            "-args",
            try s(
                a,
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
        },

        .remove, .start, .stop, .enable, .disable => [_][]const u8{
            erlsrv_path,
            command,
            try s(a, "{s}_{s}", .{ rel.name, rel.name }),
        },
        .list, .help => [_][]const u8{ erlsrv_path, command },
    };
}

fn erlsrv(a: Allocator, command: []const u8, rel: Release) !void {
    const erlsrv_path = try erlsrvPath(a, rel);
    const argv = erlsrvArgs(a, command, erlsrv_path, rel);

    const child_proc = try std.ChildProcess.init(argv, a);
    child_proc.stdin_behavior = .Inherit;
    child_proc.stdout_behavior = .Inherit;
    _ = try child_proc.spawnAndWait();
}

fn erlsrvPath(a: Allocator, rel: Release) ![]const u8 {
    const erts_dir = try s(a, "erts-{s}", .{rel.erts_vsn});
    const erts_path = try fs.path.resolve(a, &[_][]const u8{ rel.root, erts_dir });
    if (pathExists(erts_path)) return try fs.path.join(a, &[_][]const u8{ erts_path, "bin", "erlsrv.exe" });
    return "erlsrv.exe";
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

test "service.erlsrvArgs" {
    const a = testing.allocator;
    const rel = Release{
        .boot_script = "boot_script",
        .boot_script_clean = "boot_script_clean",
        .command = "command",
        .cookie = "cookie",
        .distribution = "distribution",
        .erts_vsn = "erts_vsn",
        .extra = "extra",
        .mode = "mode",
        .name = "name",
        .node = "node",
        .prog = "prog",
        .remote_vm_args = "remote_vm_args",
        .root = "root",
        .sys_config = "sys_config",
        .tmp = "tmp",
        .vm_args = "vm_args",
        .vsn = "vsn",
        .vsn_dir = "vsn_dir",
    };

    const erlsrv_path = "erlsrv.exe";

    const add = erlsrvArgs(a, "add", erlsrv_path, rel);
    const remove = erlsrvArgs(a, "remove", erlsrv_path, rel);
    const start = erlsrvArgs(a, "start", erlsrv_path, rel);
    const stop = erlsrvArgs(a, "stop", erlsrv_path, rel);
    const enable = erlsrvArgs(a, "enable", erlsrv_path, rel);
    const disable = erlsrvArgs(a, "disable", erlsrv_path, rel);
    const list = erlsrvArgs(a, "list", erlsrv_path, rel);
    const help = erlsrvArgs(a, "help", erlsrv_path, rel);

    try testing.expectEqualSlices(add, [_][]const u8{
        "erlsrv.exe",
        "add",
        "name_name",
        "-distribution",
        "node",
        "-env",
        "RELEASE_ROOT=root",
        "-env",
        "RELEASE_NAME=name",
        "-env",
        "RELEASE_VSN=vsn",
        "-env",
        "RELEASE_MODE=mode",
        "-env",
        "RELEASE_COOKIE=cookie",
        "-env",
        "RELEASE_NODE=node",
        "-env",
        "RELEASE_VM_ARGS=vm_args",
        "-env",
        "RELEASE_TMP=tmp",
        "-env",
        "RELEASE_SYS_CONFIG=sys_config",
        "-args",
        "-setcookie cookie -config sys_config -mode mode -boot vsn_dir\\start -boot_var RELEASE_LIB root\\lib -args_file vsn_dir\\vm.args",
    });
    try testing.expectEqualSlices(remove, [_][]const u8{ "erlsrv.exe", "remove", "name_name" });
    try testing.expectEqualSlices(start, [_][]const u8{ "erlsrv.exe", "start", "name_name" });
    try testing.expectEqualSlices(stop, [_][]const u8{ "erlsrv.exe", "stop", "name_name" });
    try testing.expectEqualSlices(enable, [_][]const u8{ "erlsrv.exe", "enable", "name_name" });
    try testing.expectEqualSlices(disable, [_][]const u8{ "erlsrv.exe", "disable", "name_name" });
    try testing.expectEqualSlices(list, [_][]const u8{ "erlsrv.exe", "list" });
    try testing.expectEqualSlices(help, [_][]const u8{ "erlsrv.exe", "help" });
}
