defmodule Mix.Deps.Umbrella do
  @moduledoc false

  @doc """
  Gets all umbrella dependencies in unfetched format.
  """
  def unfetched do
    config = Mix.project

    if apps_path = config[:apps_path] do
      paths = Path.wildcard(Path.join(apps_path, "*"))

      paths
      |> Enum.filter(&File.dir?(&1))
      |> extract_umbrella
      |> filter_umbrella(config[:apps])
      |> to_umbrella_dep()
    else
      []
    end
  end

  @doc """
  Gets all umbrella dependencies in fetched format.
  """
  def fetched do
    deps = unfetched
    apps = Enum.map(deps, &(&1.app))

    Enum.map(deps, fn(umbrella_dep) ->
      { umbrella_dep, deps } = Mix.Deps.Retriever.fetch(umbrella_dep, [])
      deps = lc Mix.Dep[] = dep inlist deps,
                Mix.Deps.available?(dep),
                dep.app in apps,
                do: dep.app
      umbrella_dep.deps(deps)
    end) |> Mix.Deps.Converger.topsort
  end

  defp extract_umbrella(paths) do
    lc path inlist paths do
      app = path |> Path.basename |> String.downcase |> binary_to_atom
      { app, path }
    end
  end

  defp filter_umbrella(pairs, nil), do: pairs
  defp filter_umbrella(pairs, apps) when is_list(apps) do
    lc { app, _ } = pair inlist pairs, app in apps, do: pair
  end

  defp to_umbrella_dep(paths) do
    Enum.map paths, fn({ app, path }) ->
      Mix.Dep[scm: Mix.SCM.Path, app: app, requirement: nil, manager: :mix,
              status: { :ok, nil }, opts: [path: path, dest: Path.expand(path), env: Mix.env]]
    end
  end
end
