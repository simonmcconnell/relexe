defmodule Expkg.Helpers.Precheck do
  require Logger

  def run do
    if Enum.any?(~w(zig), &(System.find_executable(&1) == nil)) do
      Logger.error(
        "You MUST have `zig` installed to use Burrito, we couldn't find it in your PATH!"
      )

      exit(1)
    end
  end
end
