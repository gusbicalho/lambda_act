defmodule Parsers.Error do
  defmodule Expected do
    use TypedStruct

    typedstruct do
      field :completions, list(String.t()), default: []
      field :description, iodata(), enforce: true
    end

    def whitespace() do
      %__MODULE__{
        completions: [" "],
        description: "whitespace",
      }
    end
  end

  @type expected() :: Expected.t() | String.t()
  @type unexpected() :: String.t() | :end_of_input | nil

  use TypedStruct

  typedstruct do
    field :unexpected, unexpected()
    field :expected, list(expected()), default: []
    field :message, iodata()
    field :meta, list(any()), default: []
  end

  def merge(%__MODULE__{} = e1, %__MODULE__{} = e2) do
    %__MODULE__{
      unexpected: e2.unexpected || e1.unexpected,
      expected: Enum.uniq(e1.expected ++ e2.expected),
      message: e2.message || e1.message,
      meta: e1.meta ++ e2.meta,
    }
  end

  def merge(e1, e2) do
    merge(coerce_from(e1), coerce_from(e2))
  end

  @spec coerce_from(any) :: Parsers.Error.t()
  def coerce_from(%__MODULE__{} = err), do: err
  def coerce_from(err) when is_binary(err), do: %__MODULE__{message: err}
  def coerce_from(err), do: %__MODULE__{meta: err}

  @spec expected(expected() | list(expected()), any) :: __MODULE__.t()
  def expected(expected, but_found \\ :end_of_input)

  def expected(%Expected{} = expected, but_found) do
    expected([expected], but_found)
  end

  def expected(expected, but_found) when is_binary(expected) do
    expected([expected], but_found)
  end

  def expected(expected, but_found) when is_list(expected) do
    %__MODULE__{
      expected: expected,
      unexpected: but_found,
    }
  end

  def unexpected(but_found) do
    %__MODULE__{
      unexpected: but_found,
    }
  end

  @spec with_message(__MODULE__.t(), iodata()) :: __MODULE__.t()
  def with_message(%__MODULE__{} = err, message) do
    %{err | message: message}
  end

  @spec message(__MODULE__.t()) :: iodata()
  def message(%__MODULE__{} = err) do
    err.message || describe_expectations(err) || "Parse error."
  end

  @spec describe_expectations(__MODULE__.t()) :: iodata()
  def describe_expectations(%__MODULE__{expected: [], unexpected: but_found}) do
    case but_found do
      nil -> []
      :end_of_input -> ["Unexpected end of input."]
      but_found -> ["Unexpected ", but_found]
    end
  end

  def describe_expectations(%__MODULE__{expected: expected, unexpected: but_found}) do
    [
      "Expected ",
      if is_list(expected) do
        [
          "one of: ",
          expected |> Enum.map(&describe_expected/1) |> Enum.intersperse(", "),
        ]
      else
        describe_expected(expected)
      end,
      case but_found do
        nil -> "."
        :end_of_input -> ["; but reached end of input."]
        but_found -> ["; but found ", but_found]
      end,
    ]
  end

  @spec describe_expected(expected()) :: iodata()
  defp describe_expected(%Expected{description: description}) do
    description
  end

  defp describe_expected(s) when is_binary(s) do
    s
  end
end
