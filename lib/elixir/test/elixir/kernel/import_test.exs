Code.require_file "../../test_helper.exs", __FILE__

defmodule Kernel.ImportAvailable do
  defmacro flatten do
    [flatten: 1]
  end
end

defmodule Kernel.ImportOnlyTest do
  use ExUnit.Case, async: true

  require Kernel.ImportAvailable
  import :lists, only: Kernel.ImportAvailable.flatten

  test :import_erlang do
    assert flatten([1,[2],3]) == [1,2,3]
  end
end

defmodule Kernel.ImportAllTest do
  use ExUnit.Case, async: true

  import :lists

  test :import_erlang do
    assert flatten([1,[2],3]) == [1,2,3]
  end
end

defmodule Kernel.ImportExceptNoneTest do
  use ExUnit.Case, async: true

  import :lists, except: []

  test :import_erlang do
    assert flatten([1,[2],3]) == [1,2,3]
  end
end

defmodule Kernel.ImportExceptTest do
  use ExUnit.Case, async: true

  import :lists, except: [each: 2]

  test :import_erlang do
    assert flatten([1,[2],3]) == [1,2,3]
  end
end

defmodule Kernel.ImportTwiceWithExceptTest do
  use ExUnit.Case, async: true

  import :lists, except: [flatten: 1]
  import :lists, except: [each: 2]

  test :import_erlang do
    assert flatten([1,[2],3]) == [1,[2],3]
  end

  def flatten(list), do: list
end

defmodule Kernel.MessedBitwise do
  defmacro bnot(x),   do: x
  defmacro bor(x, _), do: x
end

defmodule Kernel.Underscored do
  def hello(x),          do: x
  def __underscore__(x), do: x
  def __s__(x),          do: x
end

defmodule Kernel.ExplicitUnderscored do
  def __underscore__(x), do: x * 2
end


defmodule Kernel.ImportUnderscoreTest do
  use ExUnit.Case, async: true

  import :all, Kernel.ExplicitUnderscored

  test :does_not_include_underscored do
    import Kernel.Underscored
    assert __underscore__(2) == 4
  end

  test :includes_remaining do
    import Kernel.Underscored
    assert hello(2) == 2
  end

  test :includes_sigil_like do
    import Kernel.Underscored
    assert __s__(3) == 3
  end
end

defmodule Kernel.ImportMacrosTest do
  use ExUnit.Case, async: true

  import :macros, Bitwise

  test :import_true do
    assert band(1, 1) == 1
    assert bor(0, 1) == 1
    assert bnot(0) == -1
  end

  test :function_import_with_only do
    import :macros, Bitwise, except: [bnot: 1]
    import :macros, Kernel.MessedBitwise, only: [bnot: 1]
    assert bnot(0) == 0
    assert bor(0, 1) == 1
  end

  # This test is asserting that the requires done
  # inside the function do not affect outer ones.
  test :import_true_not_affected do
    assert band(1, 1) == 1
    assert bor(0, 1) == 1
    assert bnot(0) == -1
  end
end