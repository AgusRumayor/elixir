defmodule ExUnit do
  @moduledoc """
  Basic unit test structure for Elixir.

  ## Example

  A basic setup for ExUnit is shown below:

      # File: assertion_test.exs

      # 1) Start ExUnit. You can pass some options as argument (list below)
      ExUnit.start

      # 2) Next we create a new TestCase and use ExUnit.Case
      defmodule AssertionTest do
        # 3) Notice we pass async: true, this runs the test case in parallel
        use ExUnit.Case, async: true

        # 4) A test is a method which name finishes with _test
        def test_always_pass do
          assert true
        end

        # 5) It is recommended to use the test macro instead of def
        test "the truth" do
          assert true
        end
      end

  To run the test above, all you need to to is to run the file
  using elixir from command line. Assuming you named your file
  assertion_test.exs, you can run it as:

      bin/elixir assertion_test.exs

  ## Assertions

  Check ExUnit.Assertions for assertions documentation.

  ## User config

  When started, ExUnit automatically reads a user configuration
  from the following locations, in this order:

  * $EXUNIT_CONFIG environment variable
  * $HOME/.ex_unit.exs

  If none found, no user config will be read.

  User config is an elixir file which should return a keyword list
  with ex_unit options. Please note that explicit options passed
  to start/1 or configure/1 will take precedence over user options.

      # User config example (~/.ex_unit.exs)
      [formatter: ExUnit.Formatter.ANSI]

  """

  use Application.Behaviour

  @doc false
  def start(_type, []) do
    ExUnit.Sup.start_link(user_options)
  end

  @doc """
  Starts up ExUnit and automatically set it up to run
  tests at the VM exit. It accepts a set of options to
  configure `ExUnit` (the same ones accepted by `configure/1`).

  In case you want to run tests manually, skip calling this
  function and rely on `configure/1` and `run/0` instead.
  """
  def start(options // []) do
    :application.start(:elixir)
    :application.start(:ex_unit)

    configure(options)

    System.at_exit fn
      0 ->
        failures = ExUnit.run
        System.at_exit fn _ ->
          if failures > 0, do: System.halt(1), else: System.halt(0)
        end
      _ ->
        :ok
    end
  end

  @doc """
  Returns the configured user options.
  """
  def user_options(user_config // nil) do
    user_config = user_config ||
      System.get_env("EXUNIT_CONFIG") ||
      Path.join(System.get_env("HOME"), ".ex_unit.exs")

    case File.read(user_config) do
      { :ok, contents } ->
        { config, _ } = Code.eval(contents, [], file: user_config)
        config
      _ ->
        []
    end
  end

  @doc """
  Configures ExUnit.

  ## Options

  ExUnit supports the following options given to start:

  * `:formatter` - The formatter that will print results.
                   Defaults to `ExUnit.CLIFormatter`;

  * `:max_cases` - Maximum number of cases to run in parallel.
                   Defaults to `:erlang.system_info(:schedulers_online)`;

  """
  def configure(options) do
    ExUnit.Server.merge_options(options)
  end

  @doc """
  Registers a callback to be invoked every time a
  new ExUnit process is spawned.
  """
  def after_spawn(callback) do
    ExUnit.Server.add_after_spawn(callback)
  end

  @doc """
  API used to run the tests. It is invoked automatically
  if ExUnit is started via `ExUnit.start`.

  Returns the number of failures.
  """
  def run do
    { async, sync } = ExUnit.Server.cases
    ExUnit.Runner.run async, sync, ExUnit.Server.options
  end
end
