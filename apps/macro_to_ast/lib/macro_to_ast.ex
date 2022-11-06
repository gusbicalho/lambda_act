defmodule MacroToAST do
  defmacro computation(do: steps) do
    case MacroToAST.Impl.compile_computation_block(steps) do
      {:ok, body} -> Macro.escape(body)
      {:error, error} -> raise error
    end
  end

  defmacro let(_bindings, _do_block) do
    raise "`let` outside of computation macro"
  end

  defmacro return(_value) do
    raise "`return` outside of computation macro"
  end
end

defmodule MacroToAST.Impl do
  alias AST.Terms.Computation
  alias __MODULE__
  alias __MODULE__.Apply
  alias __MODULE__.Let
  alias __MODULE__.Receive
  alias __MODULE__.Return
  alias __MODULE__.Self
  alias __MODULE__.Send
  alias __MODULE__.Spawn
  alias __MODULE__.Value
  alias __MODULE__.Helpers

  def compile_computation_block({:__block__, meta, steps}) do
    compile_steps(steps)
    |> Helpers.on_error_add_line_from(meta)
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
      {:ok, Let.sequence(step, more_steps)}
    end
  end

  def compile_computation({tag, meta, _} = form) do
    case tag do
      :let -> Let.compile(form)
      :self -> Self.compile(form)
      :spawn -> Spawn.compile(form)
      :send -> Send.compile(form)
      :return -> Return.compile(form)
      :receive -> Receive.compile(form)
      {:., _, _} -> Apply.compile(form)
      name when is_atom(name) and name not in [:fn] -> Apply.compile(form)
      _other -> test_compiling_unexpected_bare_value(form)
    end
    |> Helpers.on_error_add_line_from(meta)
  end

  def compile_computation(malformed) do
    Helpers.compile_error([], "Malformed computation #{inspect(malformed)}")
  end

  def test_compiling_unexpected_bare_value({_, meta, _} = form) do
    case Value.compile(form) do
      {:ok, _value} ->
        Helpers.compile_error(meta, "Bare value is not valid syntax. Did you mean `return <value>`?")

      _error ->
        Helpers.compile_error(meta, "Malformed computation")
    end
  end

  defmodule Let do
    def sequence(%Computation{} = step, %Computation{} = next_step) do
      %Computation{
        computation: %Computation.LetIn{
          binding: nil,
          bound: step,
          body: next_step,
        },
      }
    end

    def compile({:let, meta, bindings_and_do}) do
      {bindings, do_block} =
        Enum.split_while(bindings_and_do, fn
          {:<-, _, _} -> true
          {:=, _, _} -> true
          _ -> false
        end)

      case do_block do
        [[do: do_block]] -> compile(bindings, do_block)
        malformed -> Helpers.compile_error(meta, "Expected do block, instead got #{inspect(malformed)}")
      end
    end

    def compile(bindings, do_block) do
      with {:ok, bindings} <- Helpers.map_ok(bindings, &compile_binding/1),
           {:ok, final_comp} <- Impl.compile_computation_block(do_block) do
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
        |> Helpers.tag(:ok)
      end
    end

    defp compile_binding({:<-, _, [{name, _, nil}, bound]}) do
      with {:ok, bound} <- Impl.compile_computation_block(bound) do
        {:ok, {Helpers.binding_name_to_identifier(name), bound}}
      end
    end

    defp compile_binding({:=, _, [{name, _, nil}, bound]}) do
      with {:ok, bound} <- Value.compile(bound) do
        {:ok, {Helpers.binding_name_to_identifier(name), %Computation{computation: %Computation.Return{value: bound}}}}
      end
    end

    defp compile_binding(malformed) do
      Helpers.compile_error([], "Malformed binding: #{inspect(malformed)}")
    end
  end

  defmodule Self do
    def compile({:self, _, nil}) do
      {:ok, %Computation{computation: %Computation.Self{}}}
    end

    def compile({:self, meta, _child}) do
      Helpers.compile_error(meta, """
      `self` does not expect arguments.
      """)
    end
  end

  defmodule Spawn do
    def compile({:spawn, meta, []}) do
      Helpers.compile_error(
        meta,
        """
        spawn requires a computation body
        """
      )
    end

    def compile({:spawn, _, [[{:do, block}]]}) do
      with {:ok, block} <- Impl.compile_computation_block(block) do
        {:ok, %Computation{computation: %Computation.Spawn{body: block}}}
      end
    end

    def compile({:spawn, _, args}) do
      with {:ok, block} <- Impl.compile_steps(args) do
        {:ok, %Computation{computation: %Computation.Spawn{body: block}}}
      end
    end
  end

  defmodule Send do
    def compile({:send, _, [msg, actor]}) do
      with {:ok, msg} <- Value.compile(msg),
           {:ok, actor} <- Value.compile(actor) do
        {:ok,
         %Computation{
           computation: %Computation.Send{
             message: msg,
             actor: actor,
           },
         }}
      end
    end

    def compile({:send, meta, args}) do
      Helpers.compile_error(
        meta,
        "`send` expects two arguments, but at got #{inspect(args)}"
      )
    end
  end

  defmodule Return do
    def compile({:return, _, [value]}) do
      with {:ok, value} <- Value.compile(value) do
        {:ok,
         %Computation{
           computation: %Computation.Return{value: value},
         }}
      end
    end

    def compile({:return, meta, []}) do
      Helpers.compile_error(meta, """
      `return` expects a value.
      """)
    end

    def compile({:return, meta, _args}) do
      Helpers.compile_error(meta, """
      `return` expects exactly one value.
      """)
    end
  end

  defmodule Receive do
    def compile({:receive, _, nil}) do
      {:ok, %Computation{computation: %Computation.Receive{}}}
    end

    def compile({:receive, meta, args}) do
      Helpers.compile_error(
        meta,
        "`receive` expects no arguments, but at got #{inspect(args)}"
      )
    end
  end

  defmodule Apply do
    def compile({{:., _, [_callee]}, meta, []}) do
      Helpers.compile_error(
        meta,
        """
        Function call requires exactly one argument.
        Did you mean to use `return <value>` or `<value> []`?
        """
      )
    end

    def compile({{:., _, [function]}, _, [arg]}) do
      with {:ok, function} <- Value.compile(function),
           {:ok, arg} <- Value.compile(arg) do
        {:ok,
         %Computation{
           computation: %Computation.Apply{
             function: function,
             argument: arg,
           },
         }}
      end
    end

    def compile({{:., _, [_callee]}, meta, _args}) do
      Helpers.compile_error(
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

    def compile({name, meta, nil}) when is_atom(name) do
      Helpers.compile_error(
        meta,
        """
        Bare name #{name} is not valid syntax.
        Did you mean `return #{name}`?
        """
      )
    end

    def compile({name, meta, []}) when is_atom(name) do
      Helpers.compile_error(
        meta,
        """
        Function call #{name}() at #{inspect(meta)} requires exactly one argument.
        Did you mean `return #{name}` or `f []`?
        """
      )
    end

    def compile({name, _, [arg]}) when is_atom(name) do
      with {:ok, function} <- Value.variable(name),
           {:ok, arg} <- Value.compile(arg) do
        {:ok,
         %Computation{
           computation: %Computation.Apply{
             function: function,
             argument: arg,
           },
         }}
      end
    end

    def compile({name, meta, _args}) when is_atom(name) do
      Helpers.compile_error(
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
  end

  defmodule Value do
    alias AST.Terms.Value

    def variable(name) when is_atom(name) do
      case Helpers.binding_name_to_identifier(name) do
        nil ->
          Helpers.compile_error([], """
          The name #{name} represents a discarded binding or argument.
          It cannot be referenced.
          """)

        identifier ->
          {:ok, %Value{value: %Value.Variable{identifier: identifier}}}
      end
    end

    def compile([]) do
      {:ok, %Value{value: %Value.Unit{}}}
    end

    def compile({name, _, nil}) when is_atom(name) do
      variable(name)
    end

    def compile({:fn, _, [{:->, meta, [[], _]}]}) do
      Helpers.compile_error(
        meta,
        """
        Lambdas must have at least one argument.
        """
      )
    end

    def compile({:fn, _, [{:->, _, [args, body]}]}) do
      with {:ok, args} <-
             Helpers.map_ok(args, fn
               {name, _, nil} ->
                 {:ok, Helpers.binding_name_to_identifier(name)}

               other ->
                 {:error,
                  """
                  Malformed parameter #{inspect(other)}
                  """}
             end),
           {:ok, body} <- Impl.compile_computation_block(body) do
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
        |> Helpers.tag(:ok)
      end
    end

    def compile(malformed) do
      IO.inspect(malformed, label: "malformed value")
      # TODO
      Helpers.compile_error([], "Malformed value #{inspect(malformed)}")
    end
  end

  defmodule Helpers do
    alias AST.Terms.Identifier

    def binding_name_to_identifier(:_), do: nil
    def binding_name_to_identifier(name) when is_atom(name), do: %Identifier{id: name}

    def compile_error(meta, msg) do
      {:error,
       %CompileError{
         file: __ENV__.file,
         line: get_line(meta),
         description: msg,
       }}
    end

    def get_line(meta) do
      Keyword.get(meta, :line, nil)
    end

    def on_error_add_line_from({:error, %CompileError{line: nil} = error}, meta) do
      {:error, %{error | line: Helpers.get_line(meta)}}
    end

    def on_error_add_line_from(other, _meta), do: other

    def tag(item, tag) do
      {tag, item}
    end

    def map_ok(enumerable, f) do
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
end
