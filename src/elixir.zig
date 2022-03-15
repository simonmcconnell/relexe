const builtin = @import("builtin");
const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const process = std.process;
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");
const fatal = utils.fatal;
const release = @import("release.zig");
const Release = release.Release;
const SliceIterator = utils.SliceIterator;
const win_ansi = @cImport(@cInclude("win_ansi_fix.h"));

const RunMode = enum {
    elixir,
    elixirc,
    iex,
};

fn elixir(allocator: Allocator, rel: Release, args: []const []const u8) !void {
    var ex = std.ArrayList([]const u8).init(allocator);
    defer ex.deinit();
    var erl = std.ArrayList([]const u8).init(allocator);
    defer erl.deinit();
    var before_extra = std.ArrayList([]const u8).init(allocator);
    defer before_extra.deinit();
    var endLoop = false;
    var useWerl = false;
    var runMode = RunMode.elixir;
    var args_iter = SliceIterator{ .args = args };

    // script path
    const erts_dir = try fmt.allocPrint(allocator, "erts-{s}", .{rel.erts_vsn});
    const erts_bin = try fs.path.join(allocator, &[_][]const u8{ rel.root, erts_dir, "bin" });

    var arg: ?[]const u8 = undefined;
    var arg1: ?[]const u8 = undefined;
    var arg2: ?[]const u8 = undefined;

    while (true) {
        arg = args_iter.next() catch break;
        if (arg == null) break;
        if (mem.eql(u8, arg.?, "")) break;
        if (endLoop) try ex.append(arg.?);

        // execution options
        if (builtin.os.tag == .windows and mem.eql(u8, arg.?, "--werl")) {
            useWerl = true;
        } else if (mem.eql(u8, arg.?, "+iex")) {
            try ex.append("+iex");
            runMode = RunMode.iex;
        } else if (mem.eql(u8, arg.?, "+elixirc")) {
            try ex.append("+elixirc");
            runMode = RunMode.elixirc;
        }
        // eval paramters
        else if (mem.eql(u8, arg.?, "-e")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "--e", arg1.? });
        } else if (mem.eql(u8, arg.?, "--eval")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "--eval", arg1.? });
        } else if (mem.eql(u8, arg.?, "--rpc-eval")) {
            arg1 = try args_iter.next();
            arg2 = try args_iter.next();
            try ex.appendSlice(&.{ "--rpc-eval", arg1.?, arg2.? });
        }
        // elixir parameters
        else if (mem.eql(u8, arg.?, "-r")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "-r", arg1.? });
        } else if (mem.eql(u8, arg.?, "-pr")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "-pr", arg1.? });
        } else if (mem.eql(u8, arg.?, "-pa")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "-pa", arg1.? });
        } else if (mem.eql(u8, arg.?, "-pz")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "-pz", arg1.? });
        } else if (mem.eql(u8, arg.?, "-v")) {
            try ex.append("-v");
        } else if (mem.eql(u8, arg.?, "--app")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "--app", arg1.? });
        } else if (mem.eql(u8, arg.?, "--no-halt")) {
            try ex.append("--no-halt");
        } else if (mem.eql(u8, arg.?, "--remsh")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "--remsh", arg1.? });
        } else if (mem.eql(u8, arg.?, "--dot-iex")) {
            arg1 = try args_iter.next();
            try ex.appendSlice(&.{ "--dot-iex", arg1.? });
        }
        // erlang parameters
        else if (mem.eql(u8, arg.?, "--boot")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-boot", arg1.? });
        } else if (mem.eql(u8, arg.?, "--boot-var")) {
            arg1 = try args_iter.next();
            arg2 = try args_iter.next();
            try erl.appendSlice(&.{ "-boot_var", arg1.?, arg2.? });
        } else if (mem.eql(u8, arg.?, "--cookie")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-setcookie", arg1.? });
        } else if (mem.eql(u8, arg.?, "--hidden")) {
            try erl.append("-hidden");
        } else if (mem.eql(u8, arg.?, "--detached")) {
            log.warn("the --detached option is deprecated", .{});
            try erl.append("-detached");
        } else if (mem.eql(u8, arg.?, "--erl-config")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-config", arg1.? });
        } else if (mem.eql(u8, arg.?, "--logger-otp-reports")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-logger", "handle_otp_reports", arg1.? });
        } else if (mem.eql(u8, arg.?, "--logger-sasl-reports")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-logger", "handle_sasl_reports", arg1.? });
        } else if (mem.eql(u8, arg.?, "--name")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-name", arg1.? });
        } else if (mem.eql(u8, arg.?, "--sname")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-sname", arg1.? });
        } else if (mem.eql(u8, arg.?, "--vm-args")) {
            arg1 = try args_iter.next();
            try erl.appendSlice(&.{ "-args_file", arg1.? });
        } else if (mem.eql(u8, arg.?, "-mode")) {
            arg1 = try args_iter.next();
            try before_extra.appendSlice(&.{ "-mode", arg1.? });
        } else if (mem.eql(u8, arg.?, "--pipe-to")) {
            if (builtin.os.tag == .windows) fatal("--pipe-to option is not supported on Windows", .{});
            // TODO: handle other OSs
        } else {
            if (arg1) |a| try ex.append(a);
            endLoop = true;
        }
    }

    //// expand erl libs - this doesn't get called in the release's batch file
    // var ext_libs = String.init(allocator);
    // defer ext_libs.deinit();
    // var lib_dir_path = try fs.path.resolve(allocator, &[_][]const u8{ rel.root, "lib" });
    // var lib_dir = try fs.openDirAbsolute(lib_dir_path, .{ .iterate = true });
    // errdefer dir.close();

    // var iterator = lib_dir.iterate();
    // var dir: ?fs.Dir.Entry = undefined;
    // while (true) {
    //     dir = iterator.next() catch break;
    //     if (dir == null) break else {
    //         if (dir.?.kind == fs.File.Kind.Directory) {
    //             try ext_libs.concat(allocator, try fmt.allocPrint(allocator, " -pa {s}", .{dir.?.name}));
    //         }
    //     }
    // }

    // enable virtual terminal sequences
    // https://docs.microsoft.com/en-us/windows/console/classic-vs-vt
    if (builtin.os.tag == .windows) win_ansi.enable_virtual_term();

    const exe = try fs.path.join(allocator, &[_][]const u8{ erts_bin, if (useWerl) "werl.exe" else "erl.exe" });
    log.debug("executable path: {s}", .{exe});

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.append(exe);
    if (process.getEnvVarOwned(allocator, "ELIXIR_ERL_OPTIONS")) |elixir_erl_options| try argv.append(elixir_erl_options) else |_| {}
    try argv.appendSlice(erl.items);
    if (runMode != RunMode.iex) try argv.appendSlice(&.{ "-noshell", "-s", "elixir", "start_cli" });
    try argv.appendSlice(&.{ "-elixir", "ansi_enabled", "true" });
    try argv.appendSlice(before_extra.items);
    try argv.append("-extra");
    try argv.appendSlice(ex.items);

    var env_map = try std.process.getEnvMap(allocator);
    try putReleaseValues(&env_map, rel);

    for (argv.items) |a, i| log.debug("erl.exe arg[{d: >2}] {s}", .{ i, a });
    const child_proc = try std.ChildProcess.init(argv.items, allocator);
    child_proc.env_map = &env_map;
    child_proc.stdin_behavior = .Inherit;
    child_proc.stdout_behavior = .Inherit;
    child_proc.cwd = rel.vsn_dir;
    const exec_result = try child_proc.spawnAndWait();
    log.debug("Elixir run result: {s}", .{exec_result});
}

fn putReleaseValues(map: *std.BufMap, rel: Release) !void {
    try map.put("RELEASE_BOOT_SCRIPT", rel.boot_script);
    try map.put("RELEASE_BOOT_SCRIPT_CLEAN", rel.boot_script_clean);
    try map.put("RELEASE_COMMAND", rel.command);
    try map.put("RELEASE_COOKIE", rel.cookie);
    try map.put("RELEASE_DISTRIBUTION", rel.distribution);
    try map.put("ERTS_VSN", rel.erts_vsn);
    // TODO: extra?
    try map.put("RELEASE_MODE", rel.mode);
    try map.put("RELEASE_NAME", rel.name);
    try map.put("RELEASE_NODE", rel.node);
    try map.put("RELEASE_PROG", rel.prog);
    try map.put("RELEASE_REMOTE_VM_ARGS", rel.remote_vm_args);
    try map.put("RELEASE_ROOT", rel.root);
    try map.put("RELEASE_SYS_CONFIG", rel.sys_config);
    try map.put("RELEASE_TMP", rel.tmp);
    try map.put("RELEASE_VM_ARGS", rel.vm_args);
    try map.put("RELEASE_VSN", rel.vsn);
    try map.put("RELEASE_VSN_DIR", rel.vsn_dir);
    // todo: set vm args

    log.debug("RELEASE_BOOT_SCRIPT: {s}", .{rel.boot_script});
    log.debug("RELEASE_BOOT_SCRIPT_CLEAN: {s}", .{rel.boot_script_clean});
    log.debug("RELEASE_COMMAND: {s}", .{rel.command});
    log.debug("RELEASE_COOKIE: {s}", .{rel.cookie});
    log.debug("RELEASE_DISTRIBUTION: {s}", .{rel.distribution});
    log.debug("ERTS_VSN: {s}", .{rel.erts_vsn});
    log.debug("RELEASE_MODE: {s}", .{rel.mode});
    log.debug("RELEASE_NAME: {s}", .{rel.name});
    log.debug("RELEASE_NODE: {s}", .{rel.node});
    log.debug("RELEASE_PROG: {s}", .{rel.prog});
    log.debug("RELEASE_REMOTE_VM_ARGS: {s}", .{rel.remote_vm_args});
    log.debug("RELEASE_ROOT: {s}", .{rel.root});
    log.debug("RELEASE_SYS_CONFIG: {s}", .{rel.sys_config});
    log.debug("RELEASE_TMP: {s}", .{rel.tmp});
    log.debug("RELEASE_VM_ARGS: {s}", .{rel.vm_args});
    log.debug("RELEASE_VSN: {s}", .{rel.vsn});
    log.debug("RELEASE_VSN_DIR: {s}", .{rel.vsn_dir});
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
    for (args.items) |arg, i| log.debug("iex arg[{d}] {s}", .{ i, arg });
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
