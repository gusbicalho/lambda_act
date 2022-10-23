defmodule Parsers do
  @moduledoc """
    A parser is a function that:
      - takes a parser state
      - returns a new state and either an error, or a result
  """

  alias Parsers.Error
  alias Parsers.Internals.State

  @type parser_return(result) :: {:ok, result} | {:error, any()}
  @type parser(result) :: (State.t() -> {parser_return(result), State.t()})

  @spec run(parser(result), String.t(), Keyword.t()) :: {parser_return(result), String.t()} when result: any()
  def run(parser, text, opts \\ []) do
    {state, result} = parser.(State.new(text, opts))
    {result, state.leftovers}
  end

  def run!(parser, text, opts \\ []) do
    {{:ok, result}, leftovers} = run(parser, text, opts)
    {result, leftovers}
  end

  # basic

  def pure(value) do
    fn state ->
      {state, {:ok, value}}
    end
  end

  def fail(error) do
    fn state ->
      {state, {:error, error}}
    end
  end

  # adapters

  def with_span(parser) do
    fn %State{} = state ->
      with {new_state, {:ok, result}} <- parser.(state) do
        {new_state,
         {:ok,
          {result,
           Parsers.Position.Span.new(
             state.position,
             new_state.position,
             state.source_name
           )}}}
      end
    end
  end

  def map(parser, f) do
    fn state ->
      with {state, {:ok, r}} <- parser.(state) do
        {state, {:ok, f.(r)}}
      end
    end
  end

  def map_err(parser, f) do
    fn state ->
      with {state, {:error, r}} <- parser.(state) do
        {state, {:error, f.(r)}}
      end
    end
  end

  def validate(parser, validator) do
    fn state ->
      with {state, {:ok, r}} <- parser.(state) do
        case validator.(r) do
          nil -> {state, {:ok, r}}
          err -> {state, {:error, err}}
        end
      end
    end
  end

  def backtracking(parser) do
    fn state ->
      with {_new_state, {:error, _} = error} <- parser.(state) do
        {state, error}
      end
    end
  end

  def looking_ahead(parser) do
    fn state ->
      {_, result} = parser.(state)
      {state, result}
    end
  end

  @doc """
  If the parser fails, calls the make_recovery_parser argument with the error value.
  This call is expected to return a parser, which will then be called with the current
  (post-error) state.
  """
  def recovering_with(parser, make_recovery_parser) do
    fn state ->
      with {state, {:error, err}} <- parser.(state) do
        make_recovery_parser.(err).(state)
      end
    end
  end

  @doc """
  If the parser fails without consuming any input, runs the fallback parser.
  """
  def falling_back(parser, fallback_parser) do
    fn state ->
      case parser.(state) do
        {new_state, {:error, e1}}
        when new_state.consumed_so_far == state.consumed_so_far ->
          case fallback_parser.(state) do
            {_, {:ok, _}} = ok -> ok
            {new_state, {:error, e2}} -> {new_state, {:error, Error.merge(e1, e2)}}
          end

        other ->
          other
      end
    end
  end

  def alternatives([parser | fallbacks]) do
    Enum.reduce(
      fallbacks,
      parser,
      fn fallback, parser -> falling_back(parser, fallback) end
    )
  end

  def optional(parser) do
    parser |> falling_back(pure(nil))
  end

  def paired_with(parser, another_parser) do
    fn state ->
      with {state, {:ok, r1}} <- parser.(state),
           {state, {:ok, r2}} <- another_parser.(state) do
        {state, {:ok, {r1, r2}}}
      end
    end
  end

  def then(parser, another_parser) do
    fn state ->
      with {state, {:ok, _}} <- parser.(state),
           {state, {:ok, r2}} <- another_parser.(state) do
        {state, {:ok, r2}}
      end
    end
  end

  def also(parser, another_parser) do
    fn state ->
      with {state, {:ok, r1}} <- parser.(state),
           {state, {:ok, _}} <- another_parser.(state) do
        {state, {:ok, r1}}
      end
    end
  end

  def many(parser) do
    fn state ->
      many_go(backtracking(parser), state, [])
    end
  end

  defp many_go(parser, state, results_so_far) do
    {state, result} = parser.(state)

    case result do
      {:ok, r} -> many_go(parser, state, [r | results_so_far])
      {:error, _} -> {state, {:ok, Enum.reverse(results_so_far)}}
    end
  end

  def at_least_one(parser) do
    fn state ->
      with {state, {:ok, r_one}} <- parser.(state),
           {state, {:ok, r_more}} <- many(parser).(state) do
        {state, {:ok, [r_one | r_more]}}
      end
    end
  end

  def skip_many(parser) do
    fn state ->
      skip_many_go(backtracking(parser), state)
    end
  end

  defp skip_many_go(parser, state) do
    {state, result} = parser.(state)

    case result do
      {:ok, _} -> skip_many_go(parser, state)
      {:error, _} -> {state, {:ok, nil}}
    end
  end

  def skip_at_least_one(parser) do
    fn state ->
      with {state, {:ok, _}} <- parser.(state),
           {state, {:ok, _}} <- skip_many(parser).(state) do
        {state, {:ok, nil}}
      end
    end
  end
end
