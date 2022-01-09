const std = @import("std");

/// Stolen from clap
/// An argument iterator which iterates over a slice of arguments.
/// This implementation does not allocate.
pub const SliceIterator = struct {
    const Error = error{};

    args: []const []const u8,
    index: usize = 0,

    pub fn next(iter: *SliceIterator) Error!?[]const u8 {
        if (iter.args.len <= iter.index)
            return null;

        defer iter.index += 1;
        return iter.args[iter.index];
    }
};

test "SliceIterator" {
    const args = [_][]const u8{ "A", "BB", "CCC" };
    var iter = SliceIterator{ .args = &args };

    for (args) |arg| {
        const next_arg = try iter.next();
        std.debug.assert(std.mem.eql(u8, arg, next_arg.?));
    }
}

// read contents of a file
pub fn read(allocator: std.mem.Allocator, paths: []const []const u8, max_bytes: usize) ![]u8 {
    const path = try std.fs.path.resolve(allocator, paths);
    var f = try std.fs.openFileAbsolute(path, .{});
    const contents = try f.readToEndAlloc(allocator, max_bytes);
    f.close();
    return contents;
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}