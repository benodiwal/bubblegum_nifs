defmodule BubblegumNifs.SolanaRpc do
  alias BubblegumNifs.Error

  @moduledoc """
      HTTP Client for Solana RPC calls
  """
  use Tesla

  @type client :: Tesla.Client.t()
  @type rpc_response :: {:ok, any()} | {:error, any()}

  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.Headers, [{"content-type", "application/json"}])

  @spec new(String.t()) :: client()
  @doc """
  Creates a new Solana RPC client
  """
  def new(url) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"content-type", "application/json"}]}
    ])
  end

  @spec get_recent_blockhash(client()) :: {:ok, String.t()} | {:error, any()}
  @doc """
  Gets the recent blockhash
  """
  def get_recent_blockhash(client) do
    response =
      post(client, "", %{
        jsonrpc: "2.0",
        id: 1,
        method: "getLatestBlockhash",
        params: [%{commitment: "confirmed"}]
      })

    case response do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["result"]["value"]["blockhash"]}

      error ->
        {:error, error}
    end
  end

  @spec send_transaction(client(), BubblegumNifs.Transaction | {:error, any()}) ::
          {:ok, String.t()} | {:error, Error.t()}
  @doc """
  Sends a transaction
  """
  def send_transaction(_client, {:error, reason}) do
    {:error,
     %Error{
       type: :transaction_error,
       message: "Failed to create transaction",
       details: reason
     }}
  end

  def send_transaction(client, %BubblegumNifs.Transaction{} = transaction) do
    try do
      tx_data =
        transaction.message
        |> IO.iodata_to_binary()
        |> Base.encode64()

      case post(client, "", %{
             jsonrpc: "2.0",
             id: 1,
             method: "sendTransaction",
             params: [tx_data, %{encoding: "base64", preflightCommitment: "confirmed"}]
           }) do
        {:ok, %{status: 200, body: %{"result" => result}}} ->
          {:ok, result}

        {:ok, %{status: 200, body: %{"error" => error}}} ->
          {:error,
           %Error{
             type: :rpc_error,
             message: "Transaction failed",
             details: error
           }}

        {:error, reason} ->
          {:error,
           %Error{
             type: :rpc_error,
             message: "RPC request failed",
             details: reason
           }}
      end
    rescue
      e ->
        {:error,
         %Error{
           type: :transaction_error,
           message: "Failed to process transaction",
           details: e
         }}
    end
  end

  @spec get_account_info(client(), String.t()) ::
          {:ok, map()} | {:error, :account_not_found | any()}
  @doc """
  Gets an account info
  """
  def get_account_info(client, pubkey) do
    response =
      post(client, "", %{
        jsonrpc: "2.0",
        id: 1,
        method: "getAccountInfo",
        params: [pubkey, %{encoding: "base64", commitment: "confirmed"}]
      })

    case response do
      {:ok, %{status: 200, body: body}} ->
        if body["result"] && body["result"]["value"] do
          {:ok, body["result"]["value"]}
        else
          {:error, :account_not_found}
        end

      error ->
        {:error, error}
    end
  end

  @spec get_asset_details(client(), String.t()) :: {:ok, map()} | {:error, any()}
  @doc """
  Gets compression details for an asset using the DAS API
  """
  def get_asset_details(client, asset_id) do
    response =
      post(client, "", %{
        jsonrpc: "2.0",
        id: 1,
        method: "getAsset",
        params: %{id: asset_id}
      })

    case response do
      {:ok, %{status: 200, body: body}} ->
        if compression = get_in(body, ["result", "compression"]) do
          {:ok, compression}
        else
          {:error, :asset_not_found}
        end

      error ->
        {:error, error}
    end
  end

  @spec get_asset_proof(client(), String.t()) :: {:ok, map()} | {:error, any()}
  @doc """
  Gets the merkle proof for an asset using the DAS API
  """
  def get_asset_proof(client, asset_id) do
    response =
      post(client, "", %{
        jsonrpc: "2.0",
        id: 1,
        method: "getAssetProof",
        params: %{id: asset_id}
      })

    case response do
      {:ok, %{status: 200, body: body}} ->
        if proof = body["result"] do
          {:ok, proof}
        else
          {:error, :proof_not_found}
        end

      error ->
        {:error, error}
    end
  end

  @spec get_mint_rent(client(), integer()) :: {:ok, non_neg_integer()} | {:error, any()}
  @doc """
  Gets the minimum rent for a mint account (82 bytes).

  Returns the lamports required for rent exemption of a token mint account.
  """
  def get_mint_rent(client, account_size) do
    response =
      post(client, "", %{
        jsonrpc: "2.0",
        id: 1,
        method: "getMinimumBalanceForRentExemption",
        # Size of a mint account
        params: [account_size]
      })

    case response do
      {:ok, %{status: 200, body: body}} ->
        if is_integer(body["result"]) do
          {:ok, body["result"]}
        else
          {:error, "Invalid response format for mint rent"}
        end

      error ->
        {:error, error}
    end
  end
end
