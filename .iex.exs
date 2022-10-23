IEx.configure(inspect: [limit: :infinity, charlists: :as_lists])

if Code.ensure_loaded?(ExSync) && function_exported?(ExSync, :start, 0) do
  ExSync.start()
end
