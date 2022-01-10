defmodule Expkg.Helpers.Clean do
  require Logger

  def run(self_path) do
    Logger.info("Cleaning up...")

    cache = Path.join(self_path, "zig-cache")
    out = Path.join(self_path, "zig-out")
    metadata = Path.join(self_path, "_metadata.json")

    File.rmdir(cache)
    File.rmdir(out)
    File.rm(metadata)

    :ok
  end
end
