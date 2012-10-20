defexception Mix.NoTaskError, task: nil do
  def message(exception) do
    "The task #{task(exception)} could not be found"
  end
end

defexception Mix.InvalidTaskError, task: nil do
  def message(exception) do
    "The task #{task(exception)} does not respond to run/1"
  end
end

defexception Mix.NoProjectError,
  message: "Could not find a Mix.Project"

defexception Mix.Error,
  message: nil

defexception Mix.OutOfDateDepsError, env: nil do
  def message(exception) do
    "Some dependencies are out of date, please run `MIX_ENV=#{exception.env} mix deps.get` to proceed"
  end
end
