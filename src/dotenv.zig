const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;
const maxInt = std.math.maxInt;
const BufMap = std.BufMap;

pub const DotEnv = struct {
    const Self = @This();

    const Error = error{
        InvalidVariableName,
        SyntaxError,
        DanglingEscape,
        QuoteNotClosed,
    } || Allocator.Error || std.os.WriteError;

    arena: std.heap.ArenaAllocator,
    map: BufMap,

    pub fn init(allocator: Allocator) Self {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .map = BufMap.init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.map.deinit();
        self.arena.deinit();
    }

    pub fn parse(self: *Self, str: []const u8) !void {
        var start: usize = 0;
        var key: ?[]const u8 = null;
        var state: enum {
            SkipWhitespace,
            Key,
            ValueBegin,
            Value,
            Comment,
            Equals,
            SingleQuote,
            DoubleQuote,
        } = .SkipWhitespace;

        for (str) |c, i| {
            switch (state) {
                .SkipWhitespace => switch (c) {
                    0x09, 0x0A, 0x0D, 0x20 => {
                        // whitespace: tab, newline, carriage return, space
                    },
                    '#' => {
                        state = .Comment;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .Key;
                        start = i;
                    },
                    else => {
                        return error.SyntaxError;
                    },
                },
                .Comment => switch (c) {
                    '\n' => state = .SkipWhitespace,
                    else => {},
                },
                .Key => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    ' ', '\t' => {
                        key = str[start..i];
                        state = .Equals;
                    },
                    '=' => {
                        key = str[start..i];
                        state = .ValueBegin;
                    },
                    else => {
                        return error.InvalidVariableName;
                    },
                },
                .Equals => switch (c) {
                    ' ', '\t' => {},
                    '=' => {
                        state = .ValueBegin;
                    },
                    else => {
                        return error.SyntaxError;
                    },
                },
                .SingleQuote => switch (c) {
                    '\'' => {
                        try self.map.put(key.?, str[start..i]);
                        state = .SkipWhitespace;
                    },
                    else => {},
                },
                .DoubleQuote => switch (c) {
                    '"' => {
                        try self.map.put(key.?, str[start..i]);
                        state = .SkipWhitespace;
                    },
                    else => {},
                },
                .ValueBegin => switch (c) {
                    ' ', '\t' => {},
                    '\'' => {
                        state = .SingleQuote;
                        start = i + 1;
                    },
                    '"' => {
                        state = .DoubleQuote;
                        start = i + 1;
                    },
                    else => {
                        state = .Value;
                        start = i;
                    },
                },
                .Value => switch (c) {
                    0x09, 0x0A, 0x0D, 0x20 => {
                        // whitespace: tab, newline, carriage return, space
                        try self.map.put(key.?, str[start..i]);
                        state = .SkipWhitespace;
                    },
                    else => {},
                },
            }
        }
        switch (state) {
            .Comment, .SkipWhitespace => return,
            .Value => {
                try self.map.put(key.?, str[start..]);
                return;
            },
            .Key,
            .Equals,
            .ValueBegin,
            => return Error.SyntaxError,
            .SingleQuote, .DoubleQuote => return Error.QuoteNotClosed,
        }
    }
};

fn testDotEnvOk(str: []const u8, expect: BufMap) !void {
    var allocator = testing.allocator;
    var dotenvkv = DotEnv.init(allocator, str);
    defer dotenvkv.deinit();

    var actual = try dotenvkv.parse();
    var iter = expect.iterator();

    while (iter.next()) |entry| {
        try testing.expectEqualStrings(entry.value_ptr.*, actual.get(entry.key_ptr.*).?);
        actual.remove(entry.key_ptr.*);
    }
    try testing.expect(0 == actual.count());
}

test "DotEnv" {
    var expected = BufMap.init(testing.allocator);
    defer expected.deinit();

    try expected.put("A", "B");
    try testDotEnvOk("A=B\n", expected);
    try testDotEnvOk("A=B\r\n", expected);
    try testDotEnvOk(" A = B ", expected);
    try testDotEnvOk("A=B", expected);

    try expected.put("A", "42");
    try testDotEnvOk("A=42\n", expected);
    try testDotEnvOk("A=42\r\n", expected);
    try testDotEnvOk(" A = 42 ", expected);
    try testDotEnvOk("\tA\t=\t42\t", expected);

    expected.remove("A");
    try expected.put("B", "quoted string");
    try expected.put("C", "single quoted string");
    try testDotEnvOk("B=\"quoted string\"\nC=\'single quoted string\'", expected);
}
