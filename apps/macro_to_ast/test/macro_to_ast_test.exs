defmodule MacroToASTTest do
  use ExUnit.Case

  import MacroToAST

  doctest MacroToAST

  Module.register_attribute(__MODULE__, :computation_case, accumulate: true)

  @computation_case {
    {AST.TestCases, :return_unit},
    computation do
      return []
    end
  }

  @computation_case {
    {AST.TestCases, :let_self_return},
    computation do
      let me <- self do
        return me
      end
    end
  }

  @computation_case {
    {AST.TestCases, :let_self_spawn_send_receive_return},
    computation do
      let me <- self,
          p <-
            (spawn do
               let msg <- receive, do: send(msg, me)
             end),
          _ <- send([], p),
          response <- receive do
        return response
      end
    end
  }

  @computation_case {
    {AST.TestCases, :let_apply_ignore},
    computation do
      let id <- return(fn a -> return a end),
          ignore = fn _ -> return [] end,
          me <- self,
          me <- id(me) do
        ignore(me)
        receive
      end
    end
  }

  for {expected, compiled} <- @computation_case do
    {case_name, expected} =
      case expected do
        {m, f} -> {f, apply(m, f, [])}
        {m, f, a} -> {f, apply(m, f, a)}
      end

    test case_name do
      assert unquote(Macro.escape(expected)) == unquote(Macro.escape(compiled))
    end
  end
end
