# Used by "mix format"
[
  import_deps: [:typed_struct, :nimble_parsec],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  plugins: [
    FreedomFormatter,
  ],
  trailing_comma: true,
  local_pipe_with_parens: true,
]
