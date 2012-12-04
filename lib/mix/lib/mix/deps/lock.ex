defmodule Mix.Deps.Lock do
  @moduledoc """
  This is the module responsible to manage mix.lock file.
  """

  @doc """
  Returns the lockfile path.
  """
  def lockfile do
    Mix.project[:lockfile]
  end

  @doc """
  Read the file, returns a keyword list containing
  the app name and its current lock information.
  """
  def read(file // lockfile) do
    case File.read(file) do
      { :ok, info } ->
        { value, _binding } = Code.eval(info)
        value
      { :error, _ } ->
        []
    end
  end

  @doc """
  Receives a keyword list and writes it to the disk.
  """
  def write(file // lockfile, dict) do
    lines = lc { app, rev } inlist Enum.sort(dict), rev != nil do
      %b("#{app}": #{inspect rev, raw: true})
    end

    File.write! file, "[ " <> Enum.join(lines, ",\n  ") <> " ]"
  end
end
