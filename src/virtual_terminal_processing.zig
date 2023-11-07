const std = @import("std");
const HANDLE = std.os.windows.HANDLE;
const DWORD = std.os.windows.DWORD;
const LONG_PTR = std.os.windows.LONG_PTR;
const BOOL = std.os.windows.BOOL;

// const INVALID_HANDLE_VALUE: HANDLE = @as(LONG_PTR, -1);

const SCREEN_BUFFER_CONSOLE_MODE = enum(u32) {
    ENABLE_PROCESSED_OUTPUT = 1,
    ENABLE_WRAP_AT_EOL_OUTPUT = 2,
    ENABLE_VIRTUAL_TERMINAL_PROCESSING = 4,
    DISABLE_NEWLINE_AUTO_RETURN = 8,
    ENABLE_LVB_GRID_WORLDWIDE = 16,
};

const ENABLE_VIRTUAL_TERMINAL_PROCESSING = SCREEN_BUFFER_CONSOLE_MODE.ENABLE_VIRTURAL_TERMINAL_PROCESSING;

const STD_HANDLE = enum(u32) {
    INPUT_HANDLE = 4294967286,
    OUTPUT_HANDLE = 4294967285,
    ERROR_HANDLE = 4294967284,
};

const STD_OUTPUT_HANDLE = STD_HANDLE.OUTPUT_HANDLE;

pub fn enable() bool {
    var stdout: HANDLE = GetStdHandle(STD_OUTPUT_HANDLE);

    // if (getValue(stdout) == -1) return false;
    // if (stdout == INVALID_HANDLE_VALUE) return false;

    var mode: DWORD = 0;
    if (!GetConsoleMode(stdout, &mode)) return false;

    mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;

    if (!SetConsoleMode(stdout, mode)) {
        return false;
    } else {
        return true;
    }
}

// fn getValue(ptr: *anyopaque) @TypeOf(ptr.*) {
//     return ptr.*;
// }

extern "kernel32" fn GetConsoleMode(
    hConsoleHandle: ?HANDLE,
    lpMode: ?*SCREEN_BUFFER_CONSOLE_MODE,
) callconv(@import("std").os.windows.WINAPI) BOOL;

extern "kernel32" fn SetConsoleMode(
    hConsoleHandle: ?HANDLE,
    dwMode: SCREEN_BUFFER_CONSOLE_MODE,
) callconv(@import("std").os.windows.WINAPI) BOOL;

extern "kernel32" fn GetStdHandle(
    nStdHandle: STD_HANDLE,
) callconv(@import("std").os.windows.WINAPI) HANDLE;
