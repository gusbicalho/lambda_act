defmodule TextToAST.Helpers do
  import NimbleParsec
  alias AST.Terms

  def to_atom("" <> name) do
    String.to_atom(name)
  end

  def to_identifier("" <> name) do
    to_identifier(to_atom(name))
  end

  def to_identifier(name) when is_atom(name) do
    %Terms.Identifier{id: name}
  end

  def to_variable(%Terms.Identifier{} = id) do
    %Terms.Value.Variable{identifier: id}
  end

  def to_lambda({%Terms.Identifier{} = arg_name, %Terms.Computation{} = body}) do
    %Terms.Value.Lambda{arg_name: arg_name, body: body}
  end

  def to_unit(_), do: %Terms.Value.Unit{}

  def to_value(%Terms.Value.Variable{} = var), do: %Terms.Value{value: var}
  def to_value(%Terms.Value.Unit{} = unit), do: %Terms.Value{value: unit}
  def to_value(%Terms.Value.Lambda{} = lambda), do: %Terms.Value{value: lambda}

  def to_apply({%Terms.Value{} = function, %Terms.Value{} = argument}),
    do: %Terms.Computation.Apply{function: function, argument: argument}

  def to_let_in({%Terms.Identifier{} = binding, %Terms.Computation{} = bound, %Terms.Computation{} = body}),
    do: %Terms.Computation.LetIn{binding: binding, bound: bound, body: body}

  def to_receive("receive"), do: %Terms.Computation.Receive{}
  def to_return(%Terms.Value{} = value), do: %Terms.Computation.Return{value: value}
  def to_self("self"), do: %Terms.Computation.Self{}

  def to_send({%Terms.Value{} = message, %Terms.Value{} = actor}),
    do: %Terms.Computation.Send{message: message, actor: actor}

  def to_spawn(%Terms.Computation{} = body), do: %Terms.Computation.Spawn{body: body}

  def to_computation(%Terms.Computation.Apply{} = apply), do: %Terms.Computation{computation: apply}
  def to_computation(%Terms.Computation.LetIn{} = letIn), do: %Terms.Computation{computation: letIn}
  def to_computation(%Terms.Computation.Receive{} = receive_), do: %Terms.Computation{computation: receive_}
  def to_computation(%Terms.Computation.Return{} = return), do: %Terms.Computation{computation: return}
  def to_computation(%Terms.Computation.Self{} = self), do: %Terms.Computation{computation: self}
  def to_computation(%Terms.Computation.Send{} = send), do: %Terms.Computation{computation: send}
  def to_computation(%Terms.Computation.Spawn{} = spawn), do: %Terms.Computation{computation: spawn}

  @whitespace [?\s, ?\n, ?\t]
  def whitespace(combinator \\ empty()) do
    combinator |> ignore(ascii_string(@whitespace, min: 0))
  end

  def whitespace1(combinator \\ empty()) do
    combinator |> ignore(ascii_string(@whitespace, min: 1))
  end

  def word_boundary(combinator \\ empty()) do
    combinator |> lookahead_not(ascii_char([?a..?z, ?_..?_]))
  end

  def word(combinator \\ empty(), word)

  def word(combinator, "" <> word) do
    combinator
    |> string(word)
    |> word_boundary()
  end

  def word(combinator, [] ++ words) do
    combinator
    |> choice(Enum.map(words, &word/1))
    |> word_boundary()
  end
end

defmodule TextToAST.Identifier do
  import NimbleParsec
  alias TextToAST.Helpers

  @reserved_words ~w|let in self spawn receive send return|

  def identifier(combinator \\ empty()) do
    combinator
    |> lookahead_not(Helpers.word(@reserved_words))
    |> ascii_string([?a..?z, ?_..?_], min: 1)
    |> map({Helpers, :to_identifier, []})
    |> label("identifier (a_z)")
  end
end

defmodule TextToAST.Value.Choices do
  import NimbleParsec

  alias TextToAST.Helpers
  alias TextToAST.Identifier

  def variable(combinator \\ empty()) do
    combinator |> Identifier.identifier() |> map({Helpers, :to_variable, []})
  end

  def lambda(combinator \\ empty(), computation_parsec) do
    combinator
    |> wrap(
      ignore(string("\\"))
      |> concat(Identifier.identifier())
      |> Helpers.whitespace()
      |> ignore(string("->"))
      |> Helpers.whitespace()
      |> computation_parsec.()
    )
    |> map({List, :to_tuple, []})
    |> map({Helpers, :to_lambda, []})
  end

  def unit(combinator \\ empty()) do
    combinator
    |> string("()")
    |> map({Helpers, :to_unit, []})
  end
end

defmodule TextToAST.Value do
  import NimbleParsec

  alias TextToAST.Helpers
  alias TextToAST.Value.Choices

  def value(combinator \\ empty(), computation_parsec) do
    combinator
    |> choice([
      Choices.unit(),
      Choices.lambda(computation_parsec),
      Choices.variable(),
    ])
    |> map({Helpers, :to_value, []})
  end
end

defmodule TextToAST.Computation.Choices do
  import NimbleParsec

  alias TextToAST.Helpers
  alias TextToAST.Identifier
  alias TextToAST.Value

  def apply(combinator \\ empty(), computation_parsec) do
    combinator
    |> wrap(
      Value.value(computation_parsec)
      |> Helpers.whitespace1()
      |> Value.value(computation_parsec)
    )
    |> map({List, :to_tuple, []})
    |> map({Helpers, :to_apply, []})
    |> label("<value> <value> (apply)")
  end

  def let_in(combinator \\ empty(), computation_parser) do
    combinator
    |> ignore(Helpers.word("let"))
    |> Helpers.whitespace()
    |> wrap(
      Identifier.identifier()
      |> Helpers.whitespace()
      |> ignore(string("<-"))
      |> Helpers.whitespace()
      |> computation_parser.()
      |> Helpers.whitespace()
      |> ignore(Helpers.word("in"))
      |> Helpers.whitespace()
      |> computation_parser.()
    )
    |> map({List, :to_tuple, []})
    |> map({Helpers, :to_let_in, []})
    |> label("let <identifier> <- <computation> in <computation>")
  end

  def return(combinator \\ empty(), computation_parsec) do
    combinator
    |> ignore(Helpers.word("return"))
    |> Helpers.whitespace()
    |> Value.value(computation_parsec)
    |> map({Helpers, :to_return, []})
    |> label("return <value>")
  end

  def spawn(combinator \\ empty(), computation_parsec) do
    combinator
    |> ignore(Helpers.word("spawn"))
    |> Helpers.whitespace()
    |> ignore(string("{"))
    |> Helpers.whitespace()
    |> computation_parsec.()
    |> Helpers.whitespace()
    |> ignore(string("}"))
    |> map({Helpers, :to_spawn, []})
    |> label("spawn <Computation>")
  end

  def send(combinator \\ empty(), computation_parsec) do
    combinator
    |> ignore(Helpers.word("send"))
    |> Helpers.whitespace()
    |> wrap(
      Value.value(computation_parsec)
      # |> Helpers.whitespace()
      # |> Value.value(computation_parsec)
    )
    |> map({List, :to_tuple, []})
    |> map({Helpers, :to_send, []})
    |> label("send <value> <value>")
  end

  def receive(combinator \\ empty()) do
    combinator
    |> Helpers.word("receive")
    |> map({Helpers, :to_receive, []})
    |> label("receive")
  end

  def self(combinator \\ empty()) do
    combinator
    |> Helpers.word("self")
    |> map({Helpers, :to_self, []})
    |> label("self")
  end
end

defmodule TextToAST.Computation do
  import NimbleParsec

  alias TextToAST.Helpers
  alias TextToAST.Computation.Choices

  computation_parsec = &parsec(&1, :computation)

  defparsec :computation,
            choice([
              Choices.apply(computation_parsec),
              Choices.let_in(computation_parsec),
              Choices.return(computation_parsec),
              Choices.spawn(computation_parsec),
              Choices.send(computation_parsec),
              Choices.receive(),
              Choices.self(),
            ])
            |> map({Helpers, :to_computation, []}),
            export_combinator: true
end

defmodule TextToAST do
  import NimbleParsec

  defparsec :lambda,
            TextToAST.Value.Choices.lambda(&parsec(&1, {TextToAST.Computation, :computation}))

  defparsec :value,
            TextToAST.Value.value(&parsec(&1, {TextToAST.Computation, :computation}))

  # inline: true

  def hello do
    :world
  end
end
