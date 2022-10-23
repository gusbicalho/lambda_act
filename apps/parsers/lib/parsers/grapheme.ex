defmodule Parsers.Grapheme do
  alias Parsers.Error

  def any() do
    &any/1
  end

  def any(state) do
    case String.first(state.leftovers) do
      nil ->
        {state,
         Error.expected(%Error.Expected{
           description: "any grapheme",
         })}

      grapheme ->
        {state, {:ok, grapheme}}
    end
  end

  def matches(predicate, description \\ "grapheme matching predicate") do
    fn state ->
      case String.first(state.leftovers) do
        nil ->
          {state, {:error, Error.expected(%Error.Expected{description: description})}}

        grapheme ->
          if predicate.(grapheme) do
            {state, {:ok, grapheme}}
          else
            {state, {:error, Error.expected(%Error.Expected{description: description}, grapheme)}}
          end
      end
    end
  end
end
