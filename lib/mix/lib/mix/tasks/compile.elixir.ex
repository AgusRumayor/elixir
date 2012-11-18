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

  Note it is important to recompile all files because
  often there are compilation time dependencies between
  the files (macros and etc). However, in some cases it
  is useful to compile just the changed files for quick
  development cycles, for such, a developer can pass
  the `--quick` otion.

  ## Configuration

  * `:elixirc_options` - compilation options that applies
     to Elixir's compiler, they are: `:ignore_module_conflict`,
     `:docs` and `:debug_info`. By default, uses the same
     behaviour as Elixir

  ## Command line options

  * `--force` - forces compilation regardless of module times;
  * `--quick`, `-q` - only compile files that changed;

  """
  def run(args) do
    { opts, _ } = OptionParser.parse(args,
                    flags: [:force, :quick], aliases: [q: :quick])

    project       = Mix.project
    compile_path  = project[:compile_path]
    compile_exts  = project[:compile_exts]
    watch_exts    = project[:watch_exts]
    source_paths  = project[:source_paths]

    to_compile = Mix.Utils.extract_files(source_paths, compile_exts)
    to_watch   = Mix.Utils.extract_files(source_paths, watch_exts)
    stale      = Mix.Utils.extract_stale(to_watch, [compile_path])

    if opts[:force] or stale != [] do
      Mix.Utils.preserving_mtime(compile_path, fn ->
        File.mkdir_p! compile_path
        compile_files opts[:quick], project, compile_path, to_compile, stale
      end)
      :ok
    else
      :noop
    end
  end

  defp compile_files(true, project, compile_path, to_compile, stale) do
    opts = project[:elixirc_options] || []
    opts = Keyword.put(opts, :ignore_module_conflict, true)
    Code.compiler_options(opts)
    to_compile = lc f inlist to_compile, List.member?(stale, f), do: f
    compile_files to_compile, compile_path
  end

  defp compile_files(false, project, compile_path, to_compile, _stale) do
    Code.delete_path compile_path
    if elixir_opts = project[:elixirc_options] do
      Code.compiler_options(elixir_opts)
    end
    compile_files to_compile, compile_path
    Code.prepend_path compile_path
  end

  defp compile_files(files, to) do
    Kernel.ParallelCompiler.files_to_path files, to, fn(x) ->
      Mix.shell.info "Compiled #{x}"
      x
    end
  end
end
