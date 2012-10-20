defmodule ExUnit.Case do
  @moduledoc """
  This module is meant to be used in other modules
  as a way to configure and prepare them for testing.

  When used, it allows the following options:

  * :async - configure Elixir to run that specific test case
             in parallel with others. Must be used for performance
             when your test cases do not change any global state;

  ## Callbacks

  `ExUnit.Case` defines four callbacks:

  * `setup_all()` and `teardown_all(context)` which are executed
     before and after all tests respectively;
  * `setup(context, test)` and `teardown(context, test)` which are
     executed before and after each test, receiving the test name
     as argument;

  Such callbacks are useful to clean up any side-effect a test may cause,
  as for example, state in genservers, data on filesystem, or entries in
  a database. Data can be passed in between such callbacks as context,
  the context value returned by `setup_all` is passed down to all other
  callbacks. The value can then be updated in `setup` which is passed
  down to `teardown`.

  ## Examples

      defmodule AssertionTest do
        use ExUnit.Case, async: true

        def test_always_pass
          assert true
        end
      end

  """

  @doc false
  defmacro __using__(opts // []) do
    if Keyword.get(opts, :async, false) do
      ExUnit.Server.add_async_case(__CALLER__.module)
    else
      ExUnit.Server.add_sync_case(__CALLER__.module)
    end

    quote do
      import ExUnit.Assertions
      import ExUnit.Case
    end
  end

  @doc """
  Provides a convenient macro that allows a test to be
  defined with a string. This macro automatically inserts
  the atom :ok as the last line of the test. That said,
  a passing test always returns :ok, but, more important,
  it forces Elixir to not tail call optimize the test and
  therefore avoiding hiding lines from the backtrace.

  ## Examples

      test "true is equal to true" do
        assert true == true
      end

  """
  defmacro test(message, contents) do
    contents =
      case contents do
        [do: block] ->
          quote do
            unquote(contents)
            :ok
          end
        _ ->
          quote do
            try(unquote(contents))
            :ok
          end
      end

    quote do
      message = unquote(message)
      message = if is_binary(message) do
        :"test #{message}"
      else
        :"test_#{message}"
      end
      def message, [], [], do: unquote(Macro.escape contents)
    end
  end
end
