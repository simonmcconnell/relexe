// https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences

#ifdef _WIN32
#include <stdio.h>
#include <wchar.h>
#include <windows.h>

unsigned int enable_virtual_terminal()
{
  // Set output mode to handle virtual terminal sequences
  HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
  // this doesn't work because zig handles are usize, and INVALID_HANDLE_VALUE is -1
  // if (hOut == INVALID_HANDLE_VALUE) {
  //   return 0;
  // }

  DWORD dwMode = 0;
  if (!GetConsoleMode(hOut, &dwMode)) {
    return 0;
  }

  dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
  if (!SetConsoleMode(hOut, dwMode)) {
    return 0;
  }
  return 1;
}

#endif
