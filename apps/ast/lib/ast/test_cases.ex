defmodule AST.TestCases do
  import AST.Sugar

  def return_unit do
    return(unit())
  end

  def let_self_return do
    let_in(:me, self_(), in: return(:me))
  end

  def let_self_spawn_send_receive_return do
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
  end

  def let_apply_ignore do
    let_in(:id, return(lambda(:a, return(:a))),
      in:
        let_in(:ignore, return(lambda(nil, return(unit()))),
          in:
            let_in(:me, self_(),
              in: let_in(:me, apply_(:id, :me), in: let_in(nil, apply_(:ignore, :me), in: receive_()))
            )
        )
    )
  end
end
