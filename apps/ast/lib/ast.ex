defmodule AST do
  use TypedStruct

  defmodule Types do
    typedstruct module: Unit do
    end

    typedstruct module: ActorRef, enforce: true do
      field :mailbox, AST.Types.t()
    end

    typedstruct module: Arrow, enforce: true do
      field :argument, AST.Types.t()
      field :evaluator_mailbox, AST.Types.t()
      field :return, AST.Types.t()
    end

    typedstruct enforce: true do
      field :type, Unit.t() | ActorRef.t() | Arrow.t()
    end
  end

  defmodule Terms do
    alias __MODULE__.Computation

    typedstruct module: Identifier, enforce: true do
      field :id, atom()
    end

    defmodule Value do
      typedstruct module: Variable, enforce: true do
        field :identifier, Identifier.t()
      end

      typedstruct module: Lambda, enforce: true do
        field :arg_name, Identifier.t()
        field :body, Computation.t()
      end

      typedstruct module: Unit do
      end

      typedstruct enforce: true do
        field :value, Variable.t() | Lambda.t() | Unit.t()
      end
    end

    defmodule Computation do
      typedstruct module: Apply, enforce: true do
        field :function, Value.t()
        field :argument, Value.t()
      end

      typedstruct module: LetIn, enforce: true do
        field :binding, Identifier.t() | nil
        field :bound, Computation.t()
        field :body, Computation.t()
      end

      typedstruct module: Return, enforce: true do
        field :value, Value.t()
      end

      typedstruct module: Spawn, enforce: true do
        field :body, Computation.t()
      end

      typedstruct module: Send, enforce: true do
        field :message, Value.t()
        field :actor, Value.t()
      end

      typedstruct module: Receive, enforce: true do
      end

      typedstruct module: Self, enforce: true do
      end

      typedstruct enforce: true do
        field :computation,
              Apply.t()
              | LetIn.t()
              | Return.t()
              | Spawn.t()
              | Send.t()
              | Receive.t()
              | Self
      end
    end
  end
end
