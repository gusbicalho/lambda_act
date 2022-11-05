defmodule AST.Sugar do
  alias AST.Terms.Computation
  alias AST.Terms.Identifier
  alias AST.Terms.Value

  def identifier(%Identifier{} = id), do: id
  def identifier(nil), do: nil
  def identifier("" <> s), do: identifier(String.to_atom(s))
  def identifier(id) when is_atom(id), do: %Identifier{id: id}

  def variable(%Value.Variable{} = var), do: value(var)
  def variable(id), do: variable(%Value.Variable{identifier: identifier(id)})

  def lambda(%Value.Lambda{} = lambda), do: value(lambda)

  def lambda({arg_name, body}) do
    %Value.Lambda{
      arg_name: identifier(arg_name),
      body: computation(body),
    }
    |> lambda()
  end

  def lambda(arg_name, body), do: lambda({arg_name, body})

  @spec unit :: AST.Terms.Value.t()
  def unit(), do: value(%Value.Unit{})

  def value(%Value{} = value), do: value
  def value(%Value.Lambda{} = value), do: %Value{value: value}
  def value(%Value.Unit{} = value), do: %Value{value: value}
  def value(%Value.Variable{} = value), do: %Value{value: value}
  def value([]), do: unit()
  def value(var), do: variable(var)

  def apply(%Computation.Apply{} = apply), do: computation(apply)
  def apply({function, argument}), do: apply(%Computation.Apply{function: value(function), argument: value(argument)})
  def apply(function, argument), do: apply({function, argument})

  def let_in(%Computation.LetIn{} = let_in), do: computation(let_in)

  def let_in({binding, bound, body}) do
    %Computation.LetIn{
      binding: identifier(binding),
      bound: computation(bound),
      body: computation(body),
    }
    |> let_in()
  end

  def let_in(binding, bound, in: body), do: let_in({binding, bound, body})

  def receive_(), do: computation(%Computation.Receive{})

  def return(%Computation.Return{} = ret), do: computation(ret)
  def return(val), do: return(%Computation.Return{value: value(val)})

  def self_(), do: computation(%Computation.Self{})

  def send_(%Computation.Send{} = send), do: computation(send)
  def send_({msg, actor}), do: send_(%Computation.Send{message: value(msg), actor: value(actor)})
  def send_(msg, actor), do: send_({msg, actor})

  def spawn_(%Computation.Spawn{} = spawn), do: computation(spawn)
  def spawn_(body), do: spawn_(%Computation.Spawn{body: computation(body)})

  def seq(first, second) do
    let_in(nil, first, in: second)
  end

  def computation(%Computation{} = comp), do: comp
  def computation(%Computation.Apply{} = comp), do: %Computation{computation: comp}
  def computation(%Computation.LetIn{} = comp), do: %Computation{computation: comp}
  def computation(%Computation.Receive{} = comp), do: %Computation{computation: comp}
  def computation(%Computation.Return{} = comp), do: %Computation{computation: comp}
  def computation(%Computation.Self{} = comp), do: %Computation{computation: comp}
  def computation(%Computation.Send{} = comp), do: %Computation{computation: comp}
  def computation(%Computation.Spawn{} = comp), do: %Computation{computation: comp}
  def computation([comp]), do: computation(comp)
  def computation([comp | more_comps]), do: seq(comp, computation(more_comps))
end
