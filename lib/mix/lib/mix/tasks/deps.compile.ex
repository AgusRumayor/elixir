defmodule Mix.Tasks.Deps.Compile do
  use Mix.Task

  @shortdoc "Compile dependencies"

  @moduledoc """
  Compile dependencies.

  By default, compile all dependencies. A list of dependencies can
  be given to force the compilation of specific dependencies.

  By default, attempt to detect if the project contains one of
  the following files:

  * `mix.exs`      - if so, invokes `mix compile`
  * `rebar.config` - if so, invokes `rebar compile`
  * `Makefile`     - if so, invokes `make`

  The compilation can be customized by passing a `compile` option
  in the dependency:

      { :some_dependency, "0.1.0", git: "...", compile: "command to compile" }

  ## Command line options

  * `--quiet` - do not output verbose messages

  """

  import Mix.Deps, only: [fetched: 0, available?: 1, fetched_by_name: 1, compile_path: 1,
                          format_dep: 1, make?: 1, mix?: 1, rebar?: 1]

  def run(args) do
    Mix.Project.get! # Require the project to be available

    case OptionParser.parse(args, switches: [quiet: :boolean]) do
      { opts, [], _ } ->
        do_run(Enum.filter(fetched, &available?/1), opts)
      { opts, tail, _ } ->
        do_run(fetched_by_name(tail), opts)
    end
  end

  defp do_run(deps, run_opts) do
    shell = Mix.shell

    compiled =
      Enum.map deps, fn(dep) ->
        Mix.Dep[app: app, status: status, opts: opts] = dep

        check_unavailable!(app, status)
        unless run_opts[:quiet] || opts[:compile] == false do
          shell.info "* Compiling #{app}"
        end

        deps_path = opts[:dest]
        root_path = Path.expand(Mix.project[:deps_path])

        config = [
          deps_path: root_path,
          root_lockfile: Path.expand(Mix.project[:lockfile])
        ]

        # Avoid compilation conflicts
        ebin = compile_path(dep) |> String.to_char_list! |> Path.expand
        :code.del_path(ebin)

        compiled = cond do
          not nil?(opts[:compile]) ->
            do_compile app, deps_path, opts[:compile]
          mix?(dep) ->
            do_mix dep, config
          rebar?(dep) ->
            do_rebar app, deps_path, root_path
          make?(dep) ->
            do_command app, deps_path, "make"
          true ->
            shell.error "Could not compile #{app}, no mix.exs, rebar.config or Makefile " <>
              "(pass :compile as an option to customize compilation, set it to false to do nothing)"
        end

        Code.prepend_path(ebin)
        compiled
      end

    if Enum.any?(compiled), do: Mix.Deps.Lock.touch
  end

  defp check_unavailable!(app, { :unavailable, _ }) do
    raise Mix.Error, message: "Cannot compile dependency #{app} because " <>
      "it isn't available, run `mix deps.get` first"
  end

  defp check_unavailable!(_, _) do
    :ok
  end

  defp do_mix(dep, config) do
    Mix.Deps.in_dependency dep, config, fn _ ->
      try do
        res = Mix.Task.run("compile", ["--no-deps"])
        :ok in List.wrap(res)
      catch
        kind, reason ->
          app = dep.app
          Mix.shell.error "could not compile dependency #{app}, mix compile failed. " <>
            "You can recompile this dependency with `mix deps.compile #{app}` or " <>
            "update it with `mix deps.update #{app}`"
          :erlang.raise(kind, reason, System.stacktrace)
      end
    end
  end

  defp do_rebar(app, deps_path, root_path) do
    do_command app, deps_path, rebar_cmd(app), "compile skip_deps=true deps_dir=#{inspect root_path}"
  end

  defp rebar_cmd(app) do
    Mix.Rebar.rebar_cmd || handle_rebar_not_found(app)
  end

  defp handle_rebar_not_found(app) do
    shell = Mix.shell
    shell.info "Could not find rebar, which is needed to build #{app}"
    shell.info "I can install a local copy which is just used by mix"

    unless shell.yes?("Shall I install this local copy?") do
      raise Mix.Error, message: "Could not find rebar to compile " <>
        "dependency #{app}, please ensure rebar is available"
    end

    Mix.Task.run "local.rebar", []
    Mix.Rebar.local_rebar_cmd || raise Mix.Error, message: "rebar instalation failed"
  end

  defp do_compile(_, _deps_path, false) do
    false
  end

  defp do_compile(app, deps_path, command) when is_binary(command) do
    Mix.shell.info("#{app}: #{command}")
    do_command(app, deps_path, command)
  end

  defp do_command(app, deps_path, command, extra // "") do
    File.cd! deps_path, fn ->
      if Mix.shell.cmd("#{command} #{extra}") != 0 do
        raise Mix.Error, message: "Could not compile dependency #{app}, #{command} command failed. " <>
          "If you want to recompile this dependency, please run: mix deps.compile #{app}"
      end
    end
    true
  end
end
