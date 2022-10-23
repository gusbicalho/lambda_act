defmodule Parsers.Numbers do
  alias Parsers, as: P

  def integer do
    sign()
    |> P.paired_with(unsigned_integer())
    |> P.map(fn {sign, unsigned} -> sign * unsigned end)
  end

  def unsigned_integer() do
    P.String.at_least_one_grapheme_matching(&is_digit/1, "digit (0-9)")
    |> P.map(fn digits ->
      # match below must succeed, because we only picked digits!
      {i, ""} = Integer.parse(digits, 10)
      i
    end)
  end

  defp sign do
    P.optional(P.Grapheme.matches(is_one_of(["+", "-"])))
    |> P.map(fn
      "-" -> -1
      _ -> 1
    end)
  end

  defp is_one_of(acceptable_graphemes) do
    fn grapheme ->
      Enum.member?(acceptable_graphemes, grapheme)
    end
  end

  defp is_digit(grapheme) do
    Regex.match?(~r/^[0-9]$/, grapheme)
  end
end
