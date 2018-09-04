defmodule BlockScoutWeb.AddressContractVerificationTest do
  use BlockScoutWeb.FeatureCase, async: true

  alias Plug.Conn
  alias Explorer.Factory
  alias BlockScoutWeb.{AddressContractPage, ContractVerifyPage}

  setup do
    bypass = Bypass.open()

    Application.put_env(:explorer, :solc_bin_api_url, "http://localhost:#{bypass.port}")

    {:ok, bypass: bypass}
  end

  test "users validates smart contract", %{session: session, bypass: bypass} do
    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, solc_bin_versions()) end)

    %{name: name, source_code: source_code, bytecode: bytecode, version: version} = Factory.contract_code_info()

    transaction = :transaction |> insert() |> with_block()
    address = insert(:address, contract_code: bytecode)

    insert(
      :internal_transaction_create,
      created_contract_address: address,
      created_contract_code: bytecode,
      index: 0,
      transaction: transaction
    )

    session
    |> AddressContractPage.visit_page(address)
    |> AddressContractPage.click_verify_and_publish()
    |> ContractVerifyPage.fill_form(%{
      contract_name: name,
      version: version,
      optimization: false,
      source_code: source_code
    })
    |> ContractVerifyPage.verify_and_publish()

    assert AddressContractPage.on_page?(session, address)
  end

  test "with invalid data shows error messages", %{session: session, bypass: bypass} do
    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, solc_bin_versions()) end)

    session
    |> ContractVerifyPage.visit_page("0x1e0eaa06d02f965be2dfe0bc9ff52b2d82133461")
    |> ContractVerifyPage.fill_form(%{contract_name: "", version: nil, optimization: nil, source_code: ""})
    |> ContractVerifyPage.verify_and_publish()
    |> assert_has(ContractVerifyPage.validation_error())
  end

  defp solc_bin_versions do
    File.read!("./test/support/fixture/smart_contract/solc_bin.json")
  end
end
