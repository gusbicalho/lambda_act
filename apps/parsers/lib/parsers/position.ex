defmodule Parsers.Position do
  use TypedStruct

  typedstruct do
    field :line, integer(), enforce: true
    field :column, integer(), enforce: true
  end

  def new(line, column) do
    %__MODULE__{line: line, column: column}
  end

  defmodule Span do
    use TypedStruct

    typedstruct do
      field :start, Parsers.Position.t(), enforce: true
      field :end, Parsers.Position.t(), enforce: true
      field :source_name, String.t() | nil
    end

    def new(%Parsers.Position{} = start, %Parsers.Position{} = end_, source_name \\ nil) do
      %__MODULE__{start: start, end: end_, source_name: source_name}
    end

    def extend(
          %__MODULE__{start: this_start, end: this_end, source_name: source_name},
          %__MODULE__{start: that_start, end: that_end}
        ) do
      %__MODULE__{
        start: min(this_start, that_start),
        end: max(this_end, that_end),
        source_name: source_name,
      }
    end
  end
end
