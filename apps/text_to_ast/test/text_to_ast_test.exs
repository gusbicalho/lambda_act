defmodule TextToASTTest do
  use ExUnit.Case

  import AST.Sugar

  doctest TextToAST

  Module.register_attribute(__MODULE__, :computation_case, accumulate: true)

  @computation_case {
    {AST.TestCases, :return_unit},
    """
    return ()
    """
  }
  @computation_case {
    {AST.TestCases, :let_self_return},
    """
    let me <- self in return me
    """
  }

  @computation_case {
    {AST.TestCases, :let_self_spawn_send_receive_return},
    """
    let me <- self in
    let p <- spawn {
              let msg <- receive in
              send msg me
             } in
    let _ <- send () p in
    let response <- receive in
    return response
    """
  }

  @computation_case {
    {AST.TestCases, :let_apply_ignore},
    """
    let id <- return \\a -> return a in
    let ignore <- return \\_ -> return () in
    let me <- self in
    let me <- id me in
    let _ <- ignore me in
    receive
    """
  }

  for {expected, source} <- @computation_case do
    {case_name, expected} =
      case expected do
        {m, f} -> {f, apply(m, f, [])}
        {m, f, a} -> {f, apply(m, f, a)}
      end

    test case_name do
      assert {:ok, [result], "", _, _, _} = TextToAST.computation(unquote(source))
      assert unquote(Macro.escape(expected)) == result
    end
  end
end
