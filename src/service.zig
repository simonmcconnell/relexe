const std = @import("std");
const fmt = std.fmt;
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
    const erl_srv_command = std.meta.stringToEnum(ErlSrvCommand, command);
    return switch (erl_srv_command) {
        .add => [_][]const u8{
            erlsrv_path,
            "add",
            try fmt.allocPrint(a, "{s}_{s}", .{ rel.name, rel.name }),
            try fmt.allocPrint(a, "-{s}", .{rel.distribution}),
            rel.node,
            "-env",
            try fmt.allocPrint(a, "RELEASE_ROOT={s}", .{rel.root}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_NAME={s}", .{rel.name}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_VSN={s}", .{rel.vsn}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_MODE={s}", .{rel.mode}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_COOKIE={s}", .{rel.cookie}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_NODE={s}", .{rel.node}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_VM_ARGS={s}", .{rel.vm_args}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_TMP={s}", .{rel.tmp}),
            "-env",
            try fmt.allocPrint(a, "RELEASE_SYS_CONFIG={s}", .{rel.sys_config}),
            "-args",
            try fmt.allocPrint(
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
            try fmt.allocPrint(a, "{s}_{s}", .{ rel.name, rel.name }),
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
    const erts_dir = try fmt.allocPrint(a, "erts-{s}", .{rel.erts_vsn});
    const erts_path = try fs.path.resolve(a, &[_][]const u8{ rel.root, erts_dir });
    if (pathExists(erts_path)) return try fs.path.join(a, &[_][]const u8{ erts_path, "bin", "erlsrv.exe" });
    return "erlsrv.exe";
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

test "service.erlsrvArgs" {
    const a = std.testing.allocator;
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

    const add_args = erlsrvArgs(a, "add", erlsrv_path, rel);
    const remove_args = erlsrvArgs(a, "remove", erlsrv_path, rel);
    const start_args = erlsrvArgs(a, "start", erlsrv_path, rel);
    const stop_args = erlsrvArgs(a, "stop", erlsrv_path, rel);
    const enable_args = erlsrvArgs(a, "enable", erlsrv_path, rel);
    const disable_args = erlsrvArgs(a, "disable", erlsrv_path, rel);
    const list_args = erlsrvArgs(a, "list", erlsrv_path, rel);
    const help_args = erlsrvArgs(a, "help", erlsrv_path, rel);

    try std.testing.expectEqualSlices(add_args, [_][]const u8{
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
    try std.testing.expectEqualSlices(remove_args, [_][]const u8{ "erlsrv.exe", "remove", "name_name" });
    try std.testing.expectEqualSlices(start_args, [_][]const u8{ "erlsrv.exe", "start", "name_name" });
    try std.testing.expectEqualSlices(stop_args, [_][]const u8{ "erlsrv.exe", "stop", "name_name" });
    try std.testing.expectEqualSlices(enable_args, [_][]const u8{ "erlsrv.exe", "enable", "name_name" });
    try std.testing.expectEqualSlices(disable_args, [_][]const u8{ "erlsrv.exe", "disable", "name_name" });
    try std.testing.expectEqualSlices(list_args, [_][]const u8{ "erlsrv.exe", "list" });
    try std.testing.expectEqualSlices(help_args, [_][]const u8{ "erlsrv.exe", "help" });
}
