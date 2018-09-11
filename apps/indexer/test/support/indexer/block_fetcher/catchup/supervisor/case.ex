defmodule Indexer.BlockFetcher.Catchup.Supervisor.Case do
  alias Indexer.BlockFetcher.Catchup

  def start_supervised!(fetcher_arguments) when is_map(fetcher_arguments) do
    [fetcher_arguments]
    |> Catchup.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
