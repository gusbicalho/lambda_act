defmodule Typecheck do
  use TypedStruct

  alias AST.Terms.Computation
  alias AST.Terms.Identifier
  alias AST.Terms.Value
  alias AST.Type

  def typecheck(%Computation{} = ast) do
  end

  defmodule Context do
    typedstruct enforce: true do
      field :variables, %{atom() => Type.t()}
    end

    def with_variable(%Context{} = c, name, %Type{} = type)
        when is_atom(name) do
      update_in(c.variables, &Map.put(&1, name, type))
    end
  end

  defp check_value(context, %Value{value: value}, type), do: check_value(context, value, type)

  defp check_value(%Context{}, %Value.Unit{}, type) do
    case type do
      %Type{type: %Type.Unit{}} ->
        {:ok, %Type.Unit{}}

      other ->
        {:error,
         """
           Expected type #{inspect(other)}, but found Unit.
         """}
    end
  end

  defp check_value(context, %Value.Variable{identifier: %Identifier{id: name}}, type) do
    check_name(context, name, type)
  end

  defp check_value(context, %Value.Lambda{} = lambda, type) do
    case type do
      %Type{type: %Type.Arrow{} = arrow} ->
        with {:ok, arrow} <- check_arrow(context, lambda, arrow) do
          {:ok, %Type{type: arrow}}
        end

      other ->
        {:error,
         """
           Expected type #{inspect(type)}, but found lambda expression #{inspect(lambda)}.
         """}
    end
  end

  defp check_arrow(
         %Context{} = context,
         %Value.Lambda{arg_name: arg_name, body: body},
         %Type.Arrow{
           argument: arg_type,
           evaluator_mailbox: mailbox,
           return: return_type,
         } = arrow
       ) do
    context = Context.with_variable(context, arg_name, arg_type)

    with {:ok, _} <- check_computation(context, mailbox, body, return_type) do
      {:ok, arrow}
    end
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation{computation: computation},
         %Type{} = type
       ) do
    check_computation(context, mailbox, computation, type)
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.Apply{},
         %Type{} = type
       ) do
    # TODO
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.LetIn{},
         %Type{} = type
       ) do
    # TODO
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.Receive{},
         %Type{} = type
       ) do
    case type do
      ^mailbox ->
        {:ok, type}

      other ->
        {:error,
         """
           Expected type
             #{inspect(type)}
           but got `receive`, which has type
             #{inspect(mailbox)}
         """}
    end
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.Return{},
         %Type{} = type
       ) do
    # TODO
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.Self{},
         %Type{} = type
       ) do
    self_type = %Type{type: %Type.ActorRef{mailbox: mailbox}}

    case type do
      ^self_type ->
        {:ok, type}

      other ->
        {:error,
         """
           Expected type
             #{inspect(type)}
           but got `self`, which has type
             #{inspect(self_type)}
         """}
    end
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.Send{},
         %Type{} = type
       ) do
    # TODO
  end

  defp check_computation(
         %Context{} = context,
         %Type{} = mailbox,
         %Computation.Spawn{},
         %Type{} = type
       ) do
    # TODO
  end

  defp check_name(%Context{} = context, name, type) when is_atom(name) do
    case Map.fetch(context.variables, name) do
      {:ok, ^type} ->
        {:ok, type}

      {:ok, another_type} ->
        {:error,
         """
         Expected type
           #{inspect(type)}
         but found name #{name} which has known type
           #{inspect(another_type)}
         """}

      :error ->
        {:error,
         """
           Unknown name #{name}
         """}
    end
  end
end

defmodule D do
  import MacroToAST

  def test() do
    Typecheck.typecheck(
      computation do
        let me <- self do
          send([], me)
          receive
        end
      end
    )
  end
end
