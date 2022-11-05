defmodule AST.SugarTest do
  use ExUnit.Case

  alias AST.Terms.Computation
  alias AST.Terms.Identifier
  alias AST.Terms.Value

  Module.register_attribute(__MODULE__, :computation_case, accumulate: true)

  @computation_case {
    {AST.TestCases, :return_unit},
    %Computation{
      computation: %Computation.Return{value: %Value{value: %Value.Unit{}}},
    }
  }
  @computation_case {
    {AST.TestCases, :let_self_return},
    %Computation{
      computation: %Computation.LetIn{
        binding: %Identifier{id: :me},
        body: %Computation{
          computation: %Computation.Return{
            value: %Value{value: %Value.Variable{identifier: %Identifier{id: :me}}},
          },
        },
        bound: %Computation{computation: %Computation.Self{}},
      },
    }
  }

  @computation_case {
    {AST.TestCases, :let_self_spawn_send_receive_return},
    %Computation{
      computation: %Computation.LetIn{
        binding: %Identifier{id: :me},
        body: %Computation{
          computation: %Computation.LetIn{
            binding: %Identifier{id: :p},
            bound: %Computation{
              computation: %Computation.Spawn{
                body: %Computation{
                  computation: %Computation.LetIn{
                    binding: %Identifier{id: :msg},
                    bound: %Computation{computation: %Computation.Receive{}},
                    body: %Computation{
                      computation: %Computation.Send{
                        message: %Value{value: %Value.Variable{identifier: %Identifier{id: :msg}}},
                        actor: %Value{value: %Value.Variable{identifier: %Identifier{id: :me}}},
                      },
                    },
                  },
                },
              },
            },
            body: %Computation{
              computation: %Computation.LetIn{
                binding: nil,
                bound: %Computation{
                  computation: %Computation.Send{
                    message: %Value{value: %Value.Unit{}},
                    actor: %Value{value: %Value.Variable{identifier: %Identifier{id: :p}}},
                  },
                },
                body: %Computation{
                  computation: %Computation.LetIn{
                    binding: %Identifier{id: :response},
                    bound: %Computation{computation: %Computation.Receive{}},
                    body: %Computation{
                      computation: %Computation.Return{
                        value: %Value{value: %Value.Variable{identifier: %Identifier{id: :response}}},
                      },
                    },
                  },
                },
              },
            },
          },
        },
        bound: %Computation{computation: %Computation.Self{}},
      },
    }
  }

  @computation_case {
    {AST.TestCases, :let_apply_ignore},
    %Computation{
      computation: %Computation.LetIn{
        binding: %Identifier{id: :id},
        body: %Computation{
          computation: %Computation.LetIn{
            binding: %Identifier{id: :ignore},
            bound: %Computation{
              computation: %Computation.Return{
                value: %Value{
                  value: %Value.Lambda{
                    arg_name: nil,
                    body: %Computation{computation: %Computation.Return{value: %Value{value: %Value.Unit{}}}},
                  },
                },
              },
            },
            body: %Computation{
              computation: %Computation.LetIn{
                binding: %Identifier{id: :me},
                bound: %Computation{computation: %Computation.Self{}},
                body: %Computation{
                  computation: %Computation.LetIn{
                    binding: %Identifier{id: :me},
                    bound: %Computation{
                      computation: %Computation.Apply{
                        function: %Value{value: %Value.Variable{identifier: %Identifier{id: :id}}},
                        argument: %Value{value: %Value.Variable{identifier: %Identifier{id: :me}}},
                      },
                    },
                    body: %Computation{
                      computation: %Computation.LetIn{
                        binding: nil,
                        bound: %Computation{
                          computation: %Computation.Apply{
                            function: %Value{value: %Value.Variable{identifier: %Identifier{id: :ignore}}},
                            argument: %Value{value: %Value.Variable{identifier: %Identifier{id: :me}}},
                          },
                        },
                        body: %Computation{computation: %Computation.Receive{}},
                      },
                    },
                  },
                },
              },
            },
          },
        },
        bound: %Computation{
          computation: %Computation.Return{
            value: %Value{
              value: %Value.Lambda{
                arg_name: %Identifier{id: :a},
                body: %Computation{
                  computation: %Computation.Return{
                    value: %Value{value: %Value.Variable{identifier: %Identifier{id: :a}}},
                  },
                },
              },
            },
          },
        },
      },
    }
  }

  for {test_case, expected} <- @computation_case do
    {case_name, desugared} =
      case test_case do
        {m, f} -> {f, apply(m, f, [])}
        {m, f, a} -> {f, apply(m, f, a)}
      end

    test case_name do
      assert unquote(Macro.escape(expected)) == unquote(Macro.escape(desugared))
    end
  end
end
