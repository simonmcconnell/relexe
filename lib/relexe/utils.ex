defmodule Relexe.Utils do
  @moduledoc false

  @doc "Cast the value to a string, if it is not already one."
  @spec ensure_string(atom | String.t()) :: String.t()
  def ensure_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  def ensure_string(string) when is_binary(string), do: string
end
