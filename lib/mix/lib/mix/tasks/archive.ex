defmodule Mix.Tasks.Archive do
  use Mix.Task

  @shortdoc "Archive this project into a .ez file"

  @moduledoc """
  Packages the current project (though not its dependencies) into a
  zip file according to the specification of the
  [Erlang Archive Format](http://www.erlang.org/doc/man/code.html).

  Archives are meant to bundle small projects, usually installed
  locally.

  The file will be created in the current directory (which is expected
  to be the project root), unless an argument is supplied in which case
  the argument is expected to be the PATH where the file will be created.

  ## Command line options

  * `--no-compile` - skip compilation

  """

  def run(args) do
    { opts, _ } = OptionParser.parse(args, switches: [force: :boolean, no_compile: :boolean])

    unless opts[:no_compile] do
      Mix.Task.run :compile, args
    end

    Mix.Archive.create(".")
  end
end
