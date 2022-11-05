defmodule MacroToAST do
  alias AST.Terms.Computation
  alias AST.Terms.Identifier
  alias AST.Terms.Value

  # API
  defmacro computation(do: steps) do
    case MacroToAST.compile_computation_block(steps) do
      {:ok, body} -> Macro.escape(body)
      {:error, error} -> raise error
    end
  end

  def let(_binding) do
    raise "`let` outside of computation macro"
  end

  def return(_binding) do
    raise "`return` outside of computation macro"
  end

  # Impl

  def compile_computation_block({:__block__, _, steps}) do
    compile_steps(steps)
  end

  def compile_computation_block({_, _, _} = step), do: compile_computation(step)

  def compile_steps([]) do
    {:error, "empty block"}
  end

  def compile_steps([last_step]) do
    compile_computation(last_step)
  end

  def compile_steps([step | more_steps]) do
    with {:ok, step} <- compile_computation(step),
         {:ok, more_steps} <- compile_steps(more_steps) do
      {:ok,
       %Computation{
         computation: %Computation.LetIn{
           binding: nil,
           bound: step,
           body: more_steps,
         },
       }}
    end
  end

  def compile_computation({:let, meta, bindings_and_do}) do
    {bindings, do_block} =
      Enum.split_while(bindings_and_do, fn
        {:<-, _, _} -> true
        {:=, _, _} -> true
        _ -> false
      end)

    with {:ok, bindings} <- map_while_ok(bindings, &compile_binding/1),
         {:ok, final_comp} <- compile_do_block(meta, do_block) do
      bindings
      |> Enum.reverse()
      |> Enum.reduce(final_comp, fn {binding, bound}, acc ->
        %Computation{
          computation: %Computation.LetIn{
            binding: binding,
            bound: bound,
            body: acc,
          },
        }
      end)
      |> tag(:ok)
    end
  end

  def compile_computation({:self, meta, child}) do
    case child do
      nil ->
        {:ok, %Computation{computation: %Computation.Self{}}}

      _ ->
        compile_error(meta, """
        `self` does not expect arguments.
        """)
    end
  end

  def compile_computation({:spawn, meta, []}) do
    compile_error(
      meta,
      """
      spawn requires a computation body
      """
    )
  end

  def compile_computation({:spawn, _, [[{:do, block}]]}) do
    with {:ok, block} <- compile_computation_block(block) do
      {:ok, %Computation{computation: %Computation.Spawn{body: block}}}
    end
  end

  def compile_computation({:spawn, _, args}) do
    with {:ok, block} <- compile_steps(args) do
      {:ok, %Computation{computation: %Computation.Spawn{body: block}}}
    end
  end

  def compile_computation({:send, _, [msg, actor]}) do
    with {:ok, msg} <- compile_value(msg),
         {:ok, actor} <- compile_value(actor) do
      {:ok,
       %Computation{
         computation: %Computation.Send{
           message: msg,
           actor: actor,
         },
       }}
    end
  end

  def compile_computation({:send, meta, args}) do
    compile_error(
      meta,
      "`send` expects two arguments, but at got #{inspect(args)}"
    )
  end

  def compile_computation({:return, _, [value]}) do
    with {:ok, value} <- compile_value(value) do
      {:ok,
       %Computation{
         computation: %Computation.Return{value: value},
       }}
    end
  end

  def compile_computation({:receive, _, nil}) do
    {:ok, %Computation{computation: %Computation.Receive{}}}
  end

  def compile_computation({:receive, meta, args}) do
    compile_error(
      meta,
      "`receive` expects no arguments, but at got #{inspect(args)}"
    )
  end

  def compile_computation({{:., _, [_callee]}, meta, []}) do
    compile_error(
      meta,
      """
      Function call requires exactly one argument.
      Did you mean to use `return <value>` or `<value> []`?
      """
    )
  end

  def compile_computation({{:., _, [function]}, _, [arg]}) do
    with {:ok, function} <- compile_value(function),
         {:ok, arg} <- compile_value(arg) do
      {:ok,
       %Computation{
         computation: %Computation.Apply{
           function: function,
           argument: arg,
         },
       }}
    end
  end

  def compile_computation({{:., _, [_callee]}, meta, _args}) do
    compile_error(
      meta,
      """
      Value called with multiple arguments.
      Function calls can only take one argument at a time.
      The pattern below may do the trick:
      let f <- <function>(<first_arg>) in
      let f <- f(<second_arg>) in
      ... f(<last_arg>)
      """
    )
  end

  def compile_computation({name, meta, nil}) when is_atom(name) and name not in [:fn] do
    compile_error(
      meta,
      """
      Bare name #{name} is not valid syntax.
      Did you mean `return #{name}`?
      """
    )
  end

  def compile_computation({name, meta, []}) when is_atom(name) and name not in [:fn] do
    compile_error(
      meta,
      """
      Function call #{name}() at #{inspect(meta)} requires exactly one argument.
      Did you mean `return #{name}` or `f []`?
      """
    )
  end

  def compile_computation({name, _, [arg]}) when is_atom(name) and name not in [:fn] do
    function = %Value{value: %Value.Variable{identifier: %Identifier{id: name}}}

    with {:ok, arg} = compile_value(arg) do
      {:ok,
       %Computation{
         computation: %Computation.Apply{
           function: function,
           argument: arg,
         },
       }}
    end
  end

  def compile_computation({name, meta, _args}) when is_atom(name) and name not in [:fn] do
    compile_error(
      meta,
      """
      #{name} called with multiple arguments.
      Function calls can only take one argument at a time.
      The pattern below may do the trick:
      let #{name} <- #{name}(<first_arg>) in
      let #{name} <- #{name}(<second_arg>) in
      ... #{name}(<last_arg>)
      """
    )
  end

  def compile_computation({_, meta, _} = malformed) do
    case compile_value(malformed) do
      {:ok, _value} ->
        compile_error(
          meta,
          """
          Bare value is not valid syntax. Did you mean `return <value>`?
          """
        )

      _error ->
        compile_error(meta, "Malformed computation")
    end
  end

  def compile_computation(malformed) do
    compile_error([], "Malformed computation #{inspect(malformed)}")
  end

  def compile_binding({:<-, _, [{name, _, nil}, bound]}) do
    with {:ok, bound} <- compile_computation_block(bound) do
      {:ok, {binding_name_to_identifier(name), bound}}
    end
  end

  def compile_binding({:=, _, [{name, _, nil}, bound]}) do
    with {:ok, bound} <- compile_value(bound) do
      {:ok, {binding_name_to_identifier(name), %Computation{computation: %Computation.Return{value: bound}}}}
    end
  end

  def compile_binding(malformed) do
    compile_error([], "Malformed binding: #{inspect(malformed)}")
  end

  defp binding_name_to_identifier(:_), do: nil
  defp binding_name_to_identifier(name) when is_atom(name), do: %Identifier{id: name}

  def compile_do_block(_meta, [[do: block]]) do
    compile_computation_block(block)
  end

  def compile_do_block(meta, malformed) do
    compile_error(
      meta,
      "Expected do block, instead got #{inspect(malformed)}"
    )
  end

  def compile_value([]) do
    {:ok, %Value{value: %Value.Unit{}}}
  end

  def compile_value({name, _, nil}) when is_atom(name) do
    {:ok, %Value{value: %Value.Variable{identifier: %Identifier{id: name}}}}
  end

  def compile_value({:fn, _, [{:->, meta, [[], _]}]}) do
    compile_error(
      meta,
      """
      Lambdas must have at least one argument.
      """
    )
  end

  def compile_value({:fn, _, [{:->, _, [args, body]}]}) do
    with {:ok, args} <-
           map_while_ok(args, fn
             {name, _, nil} ->
               {:ok, binding_name_to_identifier(name)}

             other ->
               {:error,
                """
                Malformed parameter #{inspect(other)}
                """}
           end),
         {:ok, body} <- compile_computation_block(body) do
      [first_arg | more_args] = args

      more_args
      |> Enum.reverse()
      |> Enum.reduce(body, fn arg, body ->
        %Computation{
          computation: %Computation.Return{
            value: %Value{value: %Value.Lambda{arg_name: arg, body: body}},
          },
        }
      end)
      |> then(fn body ->
        %Value{value: %Value.Lambda{arg_name: first_arg, body: body}}
      end)
      |> tag(:ok)
    end
  end

  def compile_value(malformed) do
    IO.inspect(malformed, label: "malformed value")
    # TODO
    compile_error([], "Malformed value #{inspect(malformed)}")
  end

  defp compile_error(meta, msg) do
    {:error,
     %CompileError{
       file: __ENV__.file,
       line: Keyword.get(meta, :line, nil),
       description: msg,
     }}
  end

  defp tag(item, tag) do
    {tag, item}
  end

  defp map_while_ok(enumerable, f) do
    enumerable
    |> Enum.reduce_while({:ok, []}, fn element, {:ok, acc} ->
      case f.(element) do
        {:ok, element} -> {:cont, {:ok, [element | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end
end
