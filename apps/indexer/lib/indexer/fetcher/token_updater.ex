defmodule Indexer.Fetcher.TokenUpdater do
  @moduledoc """
  Updates metadata for cataloged tokens
  """
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Explorer.Token.MetadataRetriever
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.TokenUpdater.TaskSupervisor,
    metadata: [fetcher: :token_updater]
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, _reducer, _) do
    {:ok, tokens} = Chain.stream_cataloged_token_contract_address_hashes(initial, &[&1 | &2])

    tokens
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    Logger.debug("updating tokens")

    entries
    |> Enum.map(&to_string/1)
    |> MetadataRetriever.get_functions_of()
    |> case do
      {:ok, params} ->
        case Chain.import(%{
               tokens: %{params: params},
               timeout: :infinity
             }) do
          {:ok, _imported} ->
            :ok

          {:error, step, reason, _changes_so_far} ->
            Logger.error(
              fn ->
                [
                  "failed to update tokens: ",
                  inspect(reason)
                ]
              end,
              step: step
            )

            {:retry, entries}
        end

      {:error, reason} ->
        Logger.error(fn -> ["failed to update tokens: ", inspect(reason)] end,
          error_count: Enum.count(entries)
        )

        {:retry, entries}
    end
  end
end
