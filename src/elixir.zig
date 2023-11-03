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
const DotEnv = @import("dotenv.zig").DotEnv;
const Release = @import("release.zig").Release;
const SliceIterator = utils.SliceIterator;
const win_ansi = @cImport(@cInclude("win_ansi_fix.h"));

const RunMode = enum {
    elixir,
    elixirc,
    iex,
};

const Arg = enum {
    // execution options
    @"--werl",
    @"+iex",
    @"+elixirc",
    // eval paramters
    @"-e",
    @"--eval",
    @"--rpc-eval",
    // elixir parameters
    @"-r",
    @"-pr",
    @"-pa",
    @"-pz",
    @"-v",
    @"--version",
    // @"--app", DEPRECATED?
    @"--no-halt",
    @"--remsh",
    @"--dot-iex",
    @"--dbg",
    // erlang parameters
    @"--boot",
    @"--boot-var",
    @"--cookie",
    @"--hidden",
    @"--detached",
    @"--erl-config",
    @"--logger-otp-reports",
    @"--logger-sasl-reports",
    @"--sname",
    @"--vm-args",
    @"--erl",
    // @"-mode", DEPRECATED?
    @"--pipe-to",
};

pub fn elixir(allocator: Allocator, rel: Release, args: []const []const u8) !void {
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

    while (true) {
        arg = args_iter.next() catch break;
        if (arg == null) break;
        if (mem.eql(u8, arg, "")) break;
        if (endLoop) {
            try ex.append(arg);
            continue;
        }

        var argenum = std.meta.stringToEnum(Arg, arg) orelse return;

        switch (argenum) {
            // execution options
            .@"--werl" => {
                if (builtin.os.tag == .windows) useWerl = true;
            },
            .@"+iex" => {
                try ex.append("+iex");
                runMode = RunMode.iex;
            },
            .@"+elixirc" => {
                try ex.append("+elixirc");
                runMode = RunMode.elixirc;
            },

            // eval paramters
            .@"-e", .@"--eval", .@"--rpc-eval" => {
                appendArgs(&.{arg}, 1, arg, &args_iter, &ex);
            },

            // elixir parameters
            .@"-r", .@"-pr", .@"-pa", .@"-pz", .@"--remsh", .@"--dot-iex", .@"--dbg" => {
                appendArgs(&.{arg}, 1, arg, &args_iter, &ex);
            },
            .@"-v", .@"--version", .@"--no-halt" => {
                try ex.append(arg);
            },

            // erlang parameters
            .@"--boot" => {
                appendArgs(&.{"-boot"}, 1, arg, &args_iter, &erl);
            },
            .@"--boot-var" => {
                appendArgs(&.{"-boot_var"}, 2, arg, &args_iter, &erl);
            },
            .@"--cookie" => {
                appendArgs(&.{"-setcookie"}, 1, arg, &args_iter, &erl);
            },
            .@"--hidden" => {
                try erl.append("-hidden");
            },
            .@"--erl-config" => {
                appendArgs(&.{"-config"}, 1, arg, &args_iter, &erl);
            },
            .@"--logger-otp-reports" => {
                appendArgs(&.{ "-logger", "handle_otp_reports" }, 1, arg, &args_iter, &erl);
            },
            .@"--logger-sasl-reports" => {
                appendArgs(&.{ "-logger", "handle_sasl_reports" }, 1, arg, &args_iter, &erl);
            },
            .@"--name" => {
                appendArgs(&.{"-name"}, 1, arg, &args_iter, &erl);
            },
            .@"--sname" => {
                appendArgs(&.{"-sname"}, 1, arg, &args_iter, &erl);
            },
            .@"--vm-args" => {
                appendArgs(&.{"-args_file"}, 1, arg, &args_iter, &erl);
            },
            .@"--erl" => {
                appendArgs(&.{}, 0, arg, &args_iter, &before_extra);
            },
            .@"--pipe-to" => {
                if (builtin.os.tag == .windows) fatal("--pipe-to option is not supported on Windows", .{});
                // TODO: handle other OSs
            },
            else => {
                endLoop = true;
                try ex.append(arg);
            },
        }
    }

    //// expand erl libs - this doesn't get called in the release's batch file - doesn't exist in the 1.15.7 batch file
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
    if (builtin.os.tag == .windows) {
        if (win_ansi.enable_virtual_term()) {
            try before_extra.insertSlice(0, &.{ "-elixir", "ansi_enabled", "true" });
        }
    }

    const exe = if (useWerl) "werl.exe" else "erl.exe";
    const exe_path = try fs.path.join(allocator, &[_][]const u8{ erts_bin, exe });
    log.debug("executable path: {s}", .{exe_path});

    if (runMode == RunMode.iex) {
        try before_extra.insertSlice(0, &.{ "-s", "elixir", "start_iex" });
    } else {
        try before_extra.insertSlice(0, &.{ "-s", "elixir", "start_cli" });
    }

    const lib = try fs.path.join(allocator, &[_][]const u8{ rel.root, "lib" });
    const ebin = try fs.path.join(allocator, &[_][]const u8{ "lib", "elixir", "ebin" });
    try before_extra.insertSlice(0, &.{ "-noshell", "-elixir_root", lib, "-pa", ebin });

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.append(exe_path);
    // this is where !ext_libs! is inserted
    if (process.getEnvVarOwned(allocator, "ELIXIR_ERL_OPTIONS")) |elixir_erl_options| {
        try argv.append(elixir_erl_options);
    } else |_| {}
    try argv.appendSlice(erl.items);
    try argv.appendSlice(before_extra.items);
    try argv.append("-extra");
    try argv.appendSlice(ex.items);

    var env_map = try std.process.getEnvMap(allocator);
    try putReleaseValues(&env_map, rel);
    try putDotEnvValues(allocator, &env_map, rel);

    for (argv.items, 0..) |a, i| log.debug("erl.exe arg[{d: >2}] {s}", .{ i, a });

    const child_proc = try std.ChildProcess.init(argv.items, allocator);
    child_proc.env_map = &env_map;
    child_proc.stdin_behavior = .Inherit;
    child_proc.stdout_behavior = .Inherit;
    child_proc.cwd = rel.vsn_dir;
    const exec_result = try child_proc.spawnAndWait();
    log.debug("Elixir run result: {s}", .{exec_result});
}

fn appendArgs(prefix_args: [][]const u8, arg_count: usize, arg: []const u8, args_iter: *SliceIterator, args_slice: *std.ArrayList([]const u8)) void {
    var i: usize = 0;
    var argi: ?[]const u8 = undefined;

    try args_slice.appendSlice(&.{prefix_args});

    while (i < arg_count) {
        argi = args_iter.next() orelse fatal("{s} requires an argument", .{arg});
        args_slice.append(argi);
        i += 1;
    }
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

fn putDotEnvValues(allocator: Allocator, map: *std.BufMap, rel: Release) !void {
    // load values from .env.<command> or .env in release version directory ...
    const dotenv_command = try std.fmt.allocPrint(allocator, ".env.{s}", .{rel.command});
    const dotenv_command_path = try fs.path.join(allocator, &[_][]const u8{ rel.vsn_dir, dotenv_command });
    const dotenv_path = try fs.path.join(allocator, &[_][]const u8{ rel.vsn_dir, ".env" });
    var dotenv: DotEnv = DotEnv.init(allocator);
    defer dotenv.deinit();

    if (fs.cwd().openFile(dotenv_command_path, .{})) |file| {
        defer file.close();
        const bytes_read = try file.reader().readAllAlloc(allocator, 1_000_000);
        try dotenv.parse(bytes_read);
    } else |_| {
        if (fs.cwd().openFile(dotenv_path, .{})) |file| {
            defer file.close();
            const bytes_read = try file.reader().readAllAlloc(allocator, 1_000_000);
            try dotenv.parse(bytes_read);
        } else |_| {
            log.debug(".env not found", .{});
        }
    }

    // ...and add them to the provided map
    var iter = dotenv.map.iterator();

    while (iter.next()) |entry| {
        try map.put(entry.key_ptr.*, entry.value_ptr.*);
    }
}
