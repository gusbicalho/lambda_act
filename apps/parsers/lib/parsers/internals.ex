defmodule Parsers.Internals do
  alias Parsers.Position

  defmodule State do
    use TypedStruct

    typedstruct do
      field :leftovers, String.t(), enforce: true
      field :consumed_so_far, integer(), enforce: true
      field :position, Position.t(), enforce: true
      field :source_name, String.t() | nil
    end

    def new(text, opts \\ []) do
      %__MODULE__{
        leftovers: text,
        consumed_so_far: 0,
        position: Position.new(0, 0),
        source_name: opts[:source_name],
      }
    end

    def advance(state, distance) do
      {consumed, leftovers} = String.split_at(state.leftovers, distance)

      {current_line, current_col} =
        consumed
        |> String.replace(~r".*\n", "\n")
        |> String.split("\n")
        |> then(fn lines ->
          skipped_lines = Enum.count(lines) - 1
          latest_line = Enum.at(lines, -1)
          current_line = state.position.line + skipped_lines

          current_col =
            if skipped_lines == 0 do
              state.position.column + String.length(latest_line)
            else
              String.length(latest_line)
            end

          {current_line, current_col}
        end)

      %State{
        state
        | leftovers: leftovers,
          consumed_so_far: state.consumed_so_far + String.length(consumed),
          position: %Position{
            line: current_line,
            column: current_col,
          },
      }
    end
  end
end
