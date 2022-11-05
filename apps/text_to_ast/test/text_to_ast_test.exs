defmodule TextToASTTest do
  use ExUnit.Case

  import AST.Sugar

  doctest TextToAST

  Module.register_attribute(__MODULE__, :computation_case, accumulate: true)

  @computation_case {
    """
    return ()
    """,
    return(unit())
  }
  @computation_case {
    """
    let me <- self in return me
    """,
    let_in(:me, self_(), in: return(:me))
  }

  @computation_case {
    """
    let me <- self in
    let p <- spawn {
              let msg <- receive in
              send msg me
             } in
    let _ <- send () p in
    let response <- receive in
    return response
    """,
    let_in(
      :me,
      self_(),
      in:
        let_in(
          :p,
          spawn_(let_in(:msg, receive_(), in: send_(:msg, :me))),
          in: [
            send_(unit(), :p),
            let_in(:response, receive_(), in: return(:response)),
          ]
        )
    )
  }

  @computation_case {
    """
    let me <- self in
    let p <- spawn {
               let msg <- receive in
               send msg me
             } in
    let _ <- send () p in
    let response <- receive in
    return response
    """,
    let_in(
      :me,
      self_(),
      in:
        let_in(
          :p,
          spawn_(let_in(:msg, receive_(), in: send_(:msg, :me))),
          in: [
            send_(unit(), :p),
            let_in(:response, receive_(), in: return(:response)),
          ]
        )
    )
  }

  for {source, expected} <- @computation_case do
    test source do
      assert {:ok, [result], "", _, _, _} = TextToAST.computation(unquote(source))
      assert unquote(Macro.escape(expected)) == result
    end
  end
end
