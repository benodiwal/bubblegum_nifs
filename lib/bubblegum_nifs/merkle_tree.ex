defmodule BubblegumNifs.MerkleTree do
  @moduledoc """
  Functions related to Merkle tree operations
  """

  @doc """
  Gets the calculated size of a merkle tree based on depth and buffer.

  ## Parameters
    * `depth` - The depth of the merkle tree
    * `buffer` - The buffer size of the merkle tree

  ## Returns
    * `{:ok, size}` - The calculated size in bytes as a u64
    * `{:error, reason}` - Error if the request fails
  """
  @spec get_merkle_tree_size(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def get_merkle_tree_size(depth, buffer) do
    case fetch_merkle_tree_size(depth, buffer) do
      {:ok, size} -> size
      {:error, reason} ->
        # Log error and return a default size or raise an exception
        require Logger
        Logger.error("Failed to get merkle tree size: #{inspect(reason)}")
        # Fallback to a reasonable default size or raise an exception
        raise "Failed to calculate merkle tree size: #{inspect(reason)}"
    end
  end

  defp fetch_merkle_tree_size(depth, buffer) do
    url = "https://merkler-tree-serv-guzao.ondigitalocean.app/merkle-tree-size?depth=#{depth}&buffer=#{buffer}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"size" => size}} -> {:ok, size}
          {:error, decode_error} -> {:error, "Failed to decode API response: #{inspect(decode_error)}"}
          _ -> {:error, "Unexpected API response format"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "API request failed with status code: #{status_code}, body: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end
