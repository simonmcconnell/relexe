const build_options = @import("build_options");
const std = @import("std");
const Allocator = std.mem.Allocator;
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const process = std.process;

const elixir = @import("elixir.zig");
const DotEnv = @import("dotenv.zig").DotEnv;
const utils = @import("utils.zig");
const fatal = utils.fatal;

pub const Release = struct {
    boot_script: []const u8,
    boot_script_clean: []const u8,
    command: []const u8,
    cookie: []const u8,
    distribution: []const u8,
    erts_vsn: []const u8,
    extra: []const u8,
    mode: []const u8,
    name: []const u8,
    node: []const u8,
    prog: []const u8,
    remote_vm_args: []const u8,
    root: []const u8,
    sys_config: []const u8,
    tmp: []const u8,
    vm_args: []const u8,
    vsn: []const u8,
    vsn_dir: []const u8,
};

// TODO: handle possibility of RUNTIME_CONFIG=true in `sys.config`

pub fn init(allocator: Allocator, prog: []const u8, command: []const u8) !Release {
    const release_root = try fs.path.resolve(allocator, &[_][]const u8{ try fs.selfExeDirPathAlloc(allocator), "../" });

    // read erts and release versions from /releases/start_erl.data
    const start_erl_data = try utils.read(allocator, &[_][]const u8{ release_root, "releases/start_erl.data" }, 128);
    var split = mem.split(u8, start_erl_data, " ");
    const erts_vsn = split.next() orelse fatal("failed to read erts version", .{});
    const release_vsn = split.next() orelse fatal("failed to read release version", .{});
    const release_vsn_dir = try fs.path.join(allocator, &[_][]const u8{ release_root, "releases", release_vsn });

    // load values from .env.<command> or .env in release version directory
    const dotenv_command = try fmt.allocPrint(allocator, ".env.{s}", .{command});
    const dotenv_command_path = try fs.path.join(allocator, &[_][]const u8{ release_vsn_dir, dotenv_command });
    const dotenv_path = try fs.path.join(allocator, &[_][]const u8{ release_vsn_dir, ".env" });
    var dotenv: DotEnv = DotEnv.init(allocator);
    defer dotenv.deinit();

    if (fs.cwd().openFile(dotenv_command_path, .{})) |file| {
        defer file.close();
        const bytes_read = try file.reader().readAllAlloc(allocator, 1_000_000);
        try dotenv.parse(bytes_read);
        // TODO: print that the .env file is busted and provide some context
    } else |_| {
        if (fs.cwd().openFile(dotenv_path, .{})) |file| {
            defer file.close();
            const bytes_read = try file.reader().readAllAlloc(allocator, 1_000_000);
            try dotenv.parse(bytes_read);
            // TODO: print that the .env file is busted and provide some context
        } else |_| {
            log.debug(".env not found", .{});
        }
    }

    // zig fmt: off
    const default_release_cookie  = try utils.read(allocator, &[_][]const u8{ release_root, "releases", "COOKIE" }, 128);
    const default_release_tmp     = try fs.path.join(allocator, &[_][]const u8{ release_root,    "tmp" });
    const default_release_vm_args = try fs.path.join(allocator, &[_][]const u8{ release_vsn_dir, "vm.args" });
    const default_remote_vm_args  = try fs.path.join(allocator, &[_][]const u8{ release_vsn_dir, "remote.vm.args" });
    const default_sys_config      = try fs.path.join(allocator, &[_][]const u8{ release_vsn_dir, "sys" });

    return Release{
        .boot_script       = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_BOOT_SCRIPT", "start")),
        .boot_script_clean = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_BOOT_SCRIPT_CLEAN", "start_clean")),
        .command           = command,
        .cookie            = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_COOKIE", default_release_cookie)),
        .distribution      = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_DISTRIBUTION", "sname")),
        .erts_vsn          = erts_vsn,
        .extra             = "",
        .mode              = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_MODE", "embedded")),
        .name              = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_NAME", build_options.RELEASE_NAME)),
        .node              = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_NODE", build_options.RELEASE_NAME)),
        .prog              = prog,
        .remote_vm_args    = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_REMOTE_VM_ARGS", default_remote_vm_args)),
        .root              = release_root,
        .sys_config        = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_SYS_CONFIG", default_sys_config)),
        .tmp               = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_TMP", default_release_tmp)),
        .vm_args           = try allocator.dupe(u8, getEnv(allocator, &dotenv.map, "RELEASE_VM_ARGS", default_release_vm_args)),
        .vsn               = release_vsn,
        .vsn_dir           = release_vsn_dir,
    };
    // zig fmt: on

}

// get the value from the map or the environment or the provided default
fn getEnv(allocator: Allocator, map: *std.BufMap, key: []const u8, default: []const u8) []const u8 {
    if (map.get(key)) |value| {
        return value;
    } else {
        return process.getEnvVarOwned(allocator, key) catch default;
    }
}

pub fn start(allocator: Allocator, rel: Release) !void {
    var args = try std.ArrayList([]const u8).initCapacity(allocator, 14);
    defer args.deinit();
    try args.appendSlice(&.{
        rel.extra,
        "--cookie",
        rel.cookie,
    });
    // distribution flag
    if (!mem.eql(u8, rel.distribution, "none")) {
        try args.appendSlice(&.{
            try fmt.allocPrint(allocator, "--{s}", .{rel.distribution}),
            rel.node,
        });
    }
    try args.appendSlice(&.{
        "-mode",
        rel.mode,
        "--erl-config",
        rel.sys_config,
        "--boot",
        try fmt.allocPrint(allocator, "{s}\\{s}", .{ rel.vsn_dir, rel.boot_script }),
        "--boot-var",
        "RELEASE_LIB",
        try fmt.allocPrint(allocator, "{s}\\lib", .{rel.root}),
        "--vm-args",
        rel.vm_args,
    });

    try elixir(allocator, rel, args.items);
}

pub fn iex(allocator: Allocator, rel: Release, iex_args: []const []const u8) !void {
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();
    try args.appendSlice(&.{ "--no-halt", "--erl", "-noshell -user Elixir.IEx.CLI", "+iex" });
    if (iex_args.len > 0) try args.appendSlice(iex_args);
    for (args.items, 0..) |arg, i| log.debug("iex arg[{d}] {s}", .{ i, arg });
    try elixir(
        allocator,
        rel,
        args.items,
    );
}

pub fn remote(allocator: Allocator, rel: Release) !void {
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();

    try args.appendSlice(&.{ "--werl", "--hidden", "--cookie", rel.cookie });
    // distribution flag
    if (!mem.eql(u8, rel.distribution, "none")) {
        const random = std.crypto.random.intRangeAtMost(u16, 0, 32767);
        try args.appendSlice(&.{
            try fmt.allocPrint(allocator, "--{s}", .{rel.distribution}),
            try fmt.allocPrint(allocator, "rem-{d}-{s}", .{ random, rel.node }),
        });
    }
    try args.appendSlice(&.{
        "--boot",
        try fmt.allocPrint(allocator, "{s}\\{s}", .{ rel.vsn_dir, rel.boot_script_clean }),
        "--boot-var",
        "RELEASE_LIB",
        try fmt.allocPrint(allocator, "{s}\\lib", .{rel.root}),
        "--vm-args",
        rel.vm_args,
        "--remsh",
        rel.node,
    });

    try iex(allocator, rel, args.items);
}

pub fn rpc(allocator: Allocator, rel: Release, expr: []const u8) !void {
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();
    try args.appendSlice(&.{
        "--hidden",
        "--cookie",
        rel.cookie,
    });
    // distribution flag
    if (!mem.eql(u8, rel.distribution, "none")) {
        const random = std.crypto.random.intRangeAtMost(u16, 0, 32767);
        try args.appendSlice(&.{
            try fmt.allocPrint(allocator, "--{s}", .{rel.distribution}),
            try fmt.allocPrint(allocator, "rpc-{d}-{s}", .{ random, rel.node }),
        });
    }
    try args.appendSlice(
        &.{
            "--boot",
            try fmt.allocPrint(allocator, "{s}\\{s}", .{ rel.vsn_dir, rel.boot_script_clean }),
            "--boot-var",
            "RELEASE_LIB",
            try fmt.allocPrint(allocator, "{s}\\lib", .{rel.root}),
            "--vm-args",
            rel.vm_args,
            "--rpc-eval",
            rel.node,
            expr,
        },
    );
    try elixir(allocator, rel, args.items);
}

pub fn stop(allocator: Allocator, rel: Release) !void {
    try rpc(allocator, rel, "System.stop()");
}

pub fn restart(allocator: Allocator, rel: Release) !void {
    try rpc(allocator, rel, "System.restart()");
}

pub fn pid(allocator: Allocator, rel: Release) !void {
    try rpc(allocator, rel, "IO.puts(System.pid())");
}

pub fn eval(allocator: Allocator, rel: Release, expr: []const u8) !void {
    try elixir(allocator, rel, &.{
        "--eval",
        expr,
        "--cookie",
        rel.cookie,
        "--erl-config",
        rel.sys_config,
        "--boot",
        try fmt.allocPrint(allocator, "{s}\\{s}", .{ rel.vsn_dir, rel.boot_script_clean }),
        "--boot-var",
        "RELEASE_LIB",
        try fmt.allocPrint(allocator, "{s}\\lib", .{rel.root}),
        "--vm-args",
        rel.vm_args,
    });
}
