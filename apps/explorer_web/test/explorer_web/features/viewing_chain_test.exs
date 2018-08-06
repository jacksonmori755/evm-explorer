defmodule ExplorerWeb.ViewingChainTest do
  @moduledoc false

  use ExplorerWeb.FeatureCase, async: true

  alias ExplorerWeb.{AddressPage, BlockPage, ChainPage, Notifier, TransactionPage}

  setup do
    [oldest_block | _] = Enum.map(1..4, &insert(:block, number: &1))

    block = insert(:block, number: 5)

    [oldest_transaction | _] =
      4
      |> insert_list(:transaction)
      |> with_block(block)

    :transaction
    |> insert()
    |> with_block(block)

    {:ok,
     %{
       last_shown_block: oldest_block,
       last_shown_transaction: oldest_transaction
     }}
  end

  describe "viewing addresses" do
    test "search for address", %{session: session} do
      address = insert(:address)

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(address.hash))
      |> assert_has(AddressPage.detail_hash(address))
    end
  end

  describe "viewing blocks" do
    test "search for blocks from chain page", %{session: session} do
      block = insert(:block, number: 6)

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(block.number))
      |> assert_has(BlockPage.detail_number(block))
    end

    test "blocks list", %{session: session} do
      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.blocks(count: 4))
    end

    test "viewing new blocks via live update", %{session: session, last_shown_block: last_shown_block} do
      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.blocks(count: 4))

      block = insert(:block, number: 6)

      Notifier.handle_event({:chain_event, :blocks, [block]})

      session
      |> assert_has(ChainPage.blocks(count: 4))
      |> assert_has(ChainPage.block(block))
      |> refute_has(ChainPage.block(last_shown_block))
    end
  end

  describe "viewing transactions" do
    test "search for transactions", %{session: session} do
      transaction = insert(:transaction)

      session
      |> ChainPage.visit_page()
      |> ChainPage.search(to_string(transaction.hash))
      |> assert_has(TransactionPage.detail_hash(transaction))
    end

    test "transactions list", %{session: session} do
      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.transactions(count: 5))
    end

    test "viewing new transactions via live update", %{
      session: session,
      last_shown_transaction: last_shown_transaction
    } do
      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.transactions(count: 5))

      transaction =
        :transaction
        |> insert()
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

      session
      |> assert_has(ChainPage.transactions(count: 5))
      |> assert_has(ChainPage.transaction(transaction))
      |> refute_has(ChainPage.transaction(last_shown_transaction))
    end

    test "count of non-loaded transactions live update when batch overflow", %{session: session} do
      transaction_hashes =
        30
        |> insert_list(:transaction)
        |> with_block()
        |> Enum.map(& &1.hash)

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.transactions(count: 5))

      Notifier.handle_event({:chain_event, :transactions, transaction_hashes})

      assert_has(session, ChainPage.non_loaded_transaction_count("30"))
    end

    test "contract creation is shown for to_address", %{session: session} do
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block()

      internal_transaction =
        :internal_transaction_create
        |> insert(transaction: transaction, index: 0)
        |> with_contract_creation(contract_address)

      session
      |> ChainPage.visit_page()
      |> assert_has(ChainPage.contract_creation(internal_transaction))
    end
  end
end
