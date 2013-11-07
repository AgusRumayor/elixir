# This module is responsible for retrieving
# dependencies of a given project. This
# module and its functions are private to Mix.
defmodule Mix.Deps.Retriever do
  @moduledoc false

  @doc """
  Gets all direct children of the current `Mix.Project`
  as a `Mix.Dep` record. Umbrella project dependencies
  are included as children.
  """
  def children do
    scms = Mix.SCM.available
    from = Path.absname("mix.exs")
    Enum.map(Mix.project[:deps] || [], &to_dep(&1, scms, from)) ++
             Mix.Deps.Umbrella.unfetched
  end

  @doc """
  Fetches the given dependency information, including its
  latest status and children.
  """
  def fetch(dep, config) do
    Mix.Dep[manager: manager, scm: scm, opts: opts] = dep
    dep  = dep.status(scm_status(scm, opts))
    dest = opts[:dest]

    { dep, children } =
      cond do
        not ok?(dep.status) ->
          { dep, [] }

        manager == :rebar ->
          rebar_dep(dep, config)

        mix?(dest) ->
          mix_dep(dep.manager(:mix), config)

        rebar?(dest) ->
          rebar_dep(dep.manager(:rebar), config)

        make?(dest) ->
          { dep.manager(:make), [] }

        true ->
          mix_dep(dep.manager(:mix), config)
      end

    { validate_app(dep), children }
  end

  @doc """
  Checks if a requirement from a dependency matches
  the given version.
  """
  def vsn_match?(nil, _actual), do: true
  def vsn_match?(req, actual) when is_regex(req), do: actual =~ req
  def vsn_match?(req, actual) when is_binary(req) do
    Version.match?(actual, req)
  end

  ## Helpers

  defp to_dep(tuple, scms, from, manager // nil) do
    dep = with_scm_and_app(tuple, scms).from(from).manager(manager)

    if match?({ _, req, _ } when is_regex(req), tuple) and
        not String.ends_with?(from, "rebar.config") do
      invalid_dep_format(tuple)
    end

    dep
  end

  defp with_scm_and_app({ app, opts }, scms) when is_atom(app) and is_list(opts) do
    with_scm_and_app({ app, nil, opts }, scms)
  end

  defp with_scm_and_app({ app, req, opts }, scms) when is_atom(app) and
      (is_binary(req) or is_regex(req) or req == nil) and is_list(opts) do

    path = Path.join(Mix.project[:deps_path], app)
    opts = Keyword.put(opts, :dest, path)

    { scm, opts } = Enum.find_value scms, { nil, [] }, fn(scm) ->
      (new = scm.accepts_options(app, opts)) && { scm, new }
    end

    if scm do
      Mix.Dep[
        scm: scm,
        app: app,
        requirement: req,
        status: scm_status(scm, opts),
        opts: opts
      ]
    else
      raise Mix.Error, message: "#{inspect Mix.Project.get} did not specify a supported scm " <>
                                "for app #{inspect app}, expected one of :git, :path or :in_umbrella"
    end
  end

  defp with_scm_and_app(other, _scms) do
    invalid_dep_format(other)
  end

  defp scm_status(scm, opts) do
    if scm.checked_out? opts do
      { :ok, nil }
    else
      { :unavailable, opts[:dest] }
    end
  end

  defp ok?({ :ok, _ }), do: true
  defp ok?(_), do: false

  defp mix?(dest) do
    File.regular?(Path.join(dest, "mix.exs"))
  end

  defp rebar?(dest) do
    Enum.any?(["rebar.config", "rebar.config.script"], fn file ->
      File.regular?(Path.join(dest, file))
    end) or File.regular?(Path.join(dest, "rebar"))
  end

  defp make?(dest) do
    File.regular? Path.join(dest, "Makefile")
  end

  defp invalid_dep_format(dep) do
    raise Mix.Error, message: %s(Dependency specified in the wrong format: #{inspect dep}, ) <>
      %s(expected { app :: atom, opts :: Keyword.t } | { app :: atom, requirement :: String.t, opts :: Keyword.t })
  end

  ## Fetching

  defp mix_dep(Mix.Dep[opts: opts, app: app, status: status] = dep, config) do
    Mix.Deps.in_dependency(dep, config, fn _ ->
      config  = Mix.project
      default =
        if Mix.Project.umbrella? do
          false
        else
          Path.join(config[:compile_path], "#{app}.app")
        end

      opts = Keyword.put_new(opts, :app, default)
      stat = cond do
        vsn = old_elixir_lock() -> { :elixirlock, vsn }
        req = old_elixir_req(config) -> { :elixirreq, req }
        true -> status
      end

      { dep.manager(:mix).opts(opts).status(stat), children }
    end)
  end

  defp rebar_dep(Mix.Dep[opts: opts] = dep, _config) do
    File.cd!(opts[:dest], fn ->
      config = Mix.Rebar.load_config(".")
      extra  = Dict.take(config, [:sub_dirs])
      { dep.manager(:rebar).extra(extra), rebar_children(config) }
    end)
  end

  defp rebar_children(root_config) do
    scms = Mix.SCM.available
    from = Path.absname("rebar.config")
    Mix.Rebar.recur(root_config, fn config ->
      Mix.Rebar.deps(config) |> Enum.map(&to_dep(&1, scms, from, :rebar))
    end) |> Enum.concat
  end

  defp validate_app(Mix.Dep[opts: opts, requirement: req, app: app, status: status] = dep) do
    opts_app = opts[:app]

    if not ok?(status) or opts_app == false do
      dep
    else
      path = if is_binary(opts_app), do: opts_app, else: "ebin/#{app}.app"
      path = Path.expand(path, opts[:dest])
      dep.status app_status(path, app, req)
    end
  end

  defp app_status(app_path, app, req) do
    case :file.consult(app_path) do
      { :ok, [{ :application, ^app, config }] } ->
        case List.keyfind(config, :vsn, 0) do
          { :vsn, actual } when is_list(actual) ->
            actual = iolist_to_binary(actual)
            if vsn_match?(req, actual) do
              { :ok, actual }
            else
              { :nomatchvsn, actual }
            end
          { :vsn, actual } ->
            { :invalidvsn, actual }
          nil ->
            { :invalidvsn, nil }
        end
      { :ok, _ } -> { :invalidapp, app_path }
      { :error, _ } -> { :noappfile, app_path }
    end
  end

  defp old_elixir_lock do
    old_vsn = Mix.Deps.Lock.elixir_vsn
    if old_vsn && old_vsn != System.version do
      old_vsn
    end
  end

  defp old_elixir_req(config) do
    req = config[:elixir]
    if req && not Version.match?(System.version, req) do
      req
    end
  end
end
