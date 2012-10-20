defmodule Mix.Tasks.Compile.Elixir do
  use Mix.Task

  @hidden true
  @shortdoc "Compile Elixir source files"

  @moduledoc """
  A task to compile Elixir source files.

  When this task runs, it will first check the mod times of
  all of the files to be compiled and if they haven't been
  changed since the last compilation, it will not compile
  them at all. If any one of them has changed, it compiles
  everything.

  For this reason, this task touches your `:compile_path`
  directory and sets the modification time to the current
  time and date at the end of each compilation. You can
  force compilation regardless of mod times by passing
  the `--force` option.

  A list of files can be given after the task
  name in order to select the files to compile.

  ## Configuration

  * `:elixirc_options` - compilation options that applies
     to Elixir's compiler, they are: `:ignore_module_conflict`,
     `:docs` and `:debug_info`. By default, uses the same
     behaviour as Elixir

  ## Command line options

  * `--force` - forces compilation regardless of mod times;

  """
  def run(args) do
    { opts, files } = OptionParser.parse(args, flags: [:force])

    project       = Mix.project
    compile_path  = project[:compile_path]
    compile_first = project[:compile_first]
    compile_exts  = project[:compile_exts]
    watch_exts    = project[:watch_exts]
    source_paths  = project[:source_paths]

    to_compile = Mix.Utils.extract_files(source_paths, files, compile_exts)
    to_watch   = Mix.Utils.extract_files(source_paths, files, watch_exts)

    if opts[:force] or Mix.Utils.stale?(to_watch, [compile_path]) do
      File.mkdir_p! compile_path
      Code.delete_path compile_path

      if elixir_opts = project[:elixirc_options] do
        Code.compiler_options(elixir_opts)
      end

      ordered = List.uniq compile_first ++ to_compile
      compile_files ordered, compile_path

      Code.prepend_path compile_path
      :ok
    else
      :noop
    end
  end

  defp compile_files(files, to) do
    Kernel.ParallelCompiler.files_to_path files, to, fn(x) ->
      Mix.shell.info "Compiled #{x}"
      x
    end
  end
end
