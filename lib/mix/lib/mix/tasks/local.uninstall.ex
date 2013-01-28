defmodule Mix.Tasks.Local.Uninstall do
  use Mix.Task

  @shortdoc "Uninstall local tasks"

  @moduledoc """
  Uninstall local tasks:

      mix local.uninstall task_name

  """

  def run(argv) do
    { _, argv } = OptionParser.parse(argv)
    Enum.each argv, do_uninstall(&1)
  end

  defp do_uninstall(task) do
    task = Mix.Task.get(task)
    File.rm! Path.join(Mix.Local.tasks_path, "#{task}.beam")
  end
end