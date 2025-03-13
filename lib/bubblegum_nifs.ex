defmodule BubblegumNifs do
    @moduledoc """
    Elixir interface for Metaplex Bubblegum compressed NFTs
    """
    alias BubblegumNifs.Native
    require Logger

    defmodule Error do
      @type t :: %__MODULE__{
        type: :rpc_error | :transaction_error | :instruction_error | :validation_error,
        message: String.t(),
        details: any()
      }
      defexception [:type, :message, :details]

      def message(%__MODULE__{message: message, details: details}) do
        "#{message} - Details: #{inspect(details)}"
      end
    end

    defmodule SolanaRpc do
        @moduledoc """
            HTTP Client for Solana RPC calls
        """
        use Tesla

        @type client :: Tesla.Client.t()
        @type rpc_response :: {:ok, any()} | {:error, any()}

        plug Tesla.Middleware.JSON
        plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]

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
          response = post(client, "", %{
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
          {:error, %Error{
            type: :transaction_error,
            message: "Failed to create transaction",
            details: reason
          }}
        end

        def send_transaction(client, %BubblegumNifs.Transaction{} = transaction) do
          try do
              tx_data = transaction.message
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
                {:error, %Error{
                  type: :rpc_error,
                  message: "Transaction failed",
                  details: error
                }}

              {:error, reason} ->
                {:error, %Error{
                  type: :rpc_error,
                  message: "RPC request failed",
                  details: reason
                }}
            end
          rescue
            e ->
              {:error, %Error{
                type: :transaction_error,
                message: "Failed to process transaction",
                details: e
              }}
          end
        end

        @spec get_account_info(client(), String.t()) :: {:ok, map()} | {:error, :account_not_found | any()}
        @doc """
        Gets an account info
        """
        def get_account_info(client, pubkey) do
          response = post(client, "", %{
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
          response = post(client, "", %{
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
          response = post(client, "", %{
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
          response = post(client, "", %{
            jsonrpc: "2.0",
            id: 1,
            method: "getMinimumBalanceForRentExemption",
            params: [account_size] # Size of a mint account
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


    @doc """
    Calculates the required account size for a compressed NFT merkle tree.

    This calculation mirrors the TypeScript implementation from @metaplex-foundation/umi.

    ## Parameters
      * `max_depth` - Maximum depth of the merkle tree
      * `max_buffer_size` - Maximum buffer size for the tree
      * `canopy_depth` - Optional canopy depth (defaults to max_depth/2)

    ## Returns
      * Size in bytes needed for the tree account
    """
    @spec calculate_tree_account_size(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
    def calculate_tree_account_size(_max_depth, max_buffer_size) do
      # The minimum account size is determined by:
      # 1 byte for compression account type
      # 1 byte for version
      # 4 bytes for max_depth
      # 4 bytes for max_buffer_size
      # 1 byte for authority option
      # 32 bytes for authority
      # 8 bytes for creation slot
      # 1 byte for padding
      # 8 bytes for sequence
      # 32 bytes for active index
      # 4 bytes for buffer_size (u32)
      header_size = 1 + 1 + 4 + 4 + 1 + 32 + 8 + 1 + 8 + 32 + 4

      # Each buffer entry needs:
      # 1 byte for path
      # 32 bytes for root
      # 32 bytes for node1
      # 32 bytes for node2
      buffer_entry_size = 1 + 32 + 32 + 32
      buffer_size = max_buffer_size * buffer_entry_size

      # No canopy for safety
      canopy_size = 0

      # Total size
      total_size = header_size + buffer_size + canopy_size

      # Add a small safety margin and ensure 8-byte alignment
      aligned_size = div(total_size + 1023, 8) * 8

      aligned_size
    end

    @doc """
    Gets the minimum rent for a specific account size

    ## Parameters
      * `client` - The RPC client
      * `size` - Account size in bytes

    ## Returns
      * `{:ok, rent}` - Rent amount in lamports if successful
      * `{:error, any()}` - Error if the request fails
    """
    @spec get_rent_for_account_size(SolanaRpc.client(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, any()}
    def get_rent_for_account_size(client, size) do
      SolanaRpc.get_mint_rent(client, size)
    end

    @type rpc_url :: String.t()
    @type keypair :: BubblegumNifs.KeypairInfo.t()
    @type pubkey :: String.t()
    @type metadata :: BubblegumNifs.MetadataArgs.t()
    @type hash :: binary()
    @type nonce :: non_neg_integer()
    @type index :: non_neg_integer()
    @type asset_id :: String.t()

    @spec create_tree(rpc_url(), keypair(), non_neg_integer(), non_neg_integer(), boolean()) ::
            {:ok, map()} | {:error, Error.t()}
    @doc """
    Initializes a compressed NFT tree
    """
    def create_tree(rpc_url, payer_keypair, max_depth, max_buffer_size, public) do
      with {:ok, client} <- {:ok, SolanaRpc.new(rpc_url)},
           {:ok, merkle_tree_keypair} <- safe_generate_keypair(),
           {:ok, recent_blockhash} <- SolanaRpc.get_recent_blockhash(client),
            account_size = calculate_tree_account_size(max_depth, max_buffer_size),
           {:ok, lamports} <- get_rent_for_account_size(client, account_size),
           {:ok, tx} <- safe_create_tree_config_tx(payer_keypair, merkle_tree_keypair, max_depth, max_buffer_size, recent_blockhash, public, lamports, account_size),
           {:ok, signature} <- SolanaRpc.send_transaction(client, tx) do
        {:ok, %{
          signature: signature,
          merkle_tree: merkle_tree_keypair.pubkey,
          tree_authority: Native.get_tree_authority_pda_address(merkle_tree_keypair.pubkey)
        }}
      else
        {:error, reason} ->
          {:error, %Error{
            type: :transaction_error,
            message: "Failed to create tree",
            details: reason
          }}
      end
    end

    @spec mint_compressed_nft(
      rpc_url(),
      keypair(),
      pubkey(),
      pubkey(),
      metadata()
    ) :: {:ok, String.t()} | {:error, any()}
    @doc """
    Mints a new compressed NFT
    """
    def mint_compressed_nft(rpc_url, payer_keypair, tree_pubkey, recipient_pubkey, metadata) do
      with {:ok, client} <- {:ok, SolanaRpc.new(rpc_url)},
           tree_authority <- Native.get_tree_authority_pda_address(tree_pubkey),
           {:ok, recent_blockhash} <- SolanaRpc.get_recent_blockhash(client),
           {:ok, tx} <- safe_mint_v1_tx(
             tree_authority,
             recipient_pubkey,
             recipient_pubkey,
             tree_pubkey,
             payer_keypair,
             metadata,
             recent_blockhash
           ),
           {:ok, signature} <- SolanaRpc.send_transaction(client, tx) do
        {:ok, signature}
      else
        {:error, reason} ->
          {:error, %Error{
            type: :transaction_error,
            message: "Failed to mint compressed NFT",
            details: reason
          }}
      end
    end

    @spec mint_to_collection(
      rpc_url(),
      keypair(),
      pubkey(),
      pubkey(),
      pubkey(),
      keypair(),
      metadata()
    ) :: {:ok, String.t()} | {:error, any()}
    @doc """
    Mints a new compressed NFT to a collection
    """
    def mint_to_collection(rpc_url, payer_keypair, tree_pubkey, recipient_pubkey,
                           collection_mint, collection_authority_keypair, metadata) do
      with {:ok, client} <- {:ok, SolanaRpc.new(rpc_url)},
           tree_authority <- Native.get_tree_authority_pda_address(tree_pubkey),
           {:ok, recent_blockhash} <- SolanaRpc.get_recent_blockhash(client),
           {:ok, tx} <- safe_mint_to_collection_tx(
             tree_authority,
             recipient_pubkey,
             recipient_pubkey, # delegate is same as owner initially
             tree_pubkey,
             payer_keypair,
             collection_authority_keypair.pubkey,
             collection_mint,
             "", # Empty string for PDA derivation in Rust
             "", # Empty string for PDA derivation in Rust
             metadata,
             recent_blockhash
           ),
           {:ok, signature} <- SolanaRpc.send_transaction(client, tx) do
        {:ok, signature}
      else
        {:error, reason} ->
          {:error, %Error{
            type: :transaction_error,
            message: "Failed to mint to collection",
            details: reason
          }}
      end
    end

    @spec transfer_compressed_nft(
      rpc_url(),
      keypair(),
      pubkey(),
      asset_id()
    ) :: {:ok, String.t()} | {:error, any()}
    @doc """
    Transfers a compressed NFT to a new owner

    This function fetches the asset proof and details from the DAS API,
    then constructs and sends the transfer transaction.
    """
    def transfer_compressed_nft(rpc_url, owner_keypair, new_owner_pubkey, asset_id) do
      client = SolanaRpc.new(rpc_url)

      with {:ok, asset} <- SolanaRpc.get_asset_details(client, asset_id),
           {:ok, proof} <- SolanaRpc.get_asset_proof(client, asset_id),
           {:ok, tree_authority} <- {:ok, Native.get_tree_authority_pda_address(asset["tree"])},
           {:ok, recent_blockhash} <- SolanaRpc.get_recent_blockhash(client),
           # Decode the base58 strings to binary
           {:ok, root} <- decode_base58(proof["root"]),
           {:ok, data_hash} <- decode_base58(asset["data_hash"]),
           {:ok, creator_hash} <- decode_base58(asset["creator_hash"]),
           # Convert proof addresses to list
           proof_addresses = proof["proof"],
           # Create transfer transaction
           {:ok, tx} <- safe_transfer_tx(
             tree_authority,
             owner_keypair.pubkey,
             owner_keypair.pubkey, # delegate is same as owner
             new_owner_pubkey,
             asset["tree"],
             root,
             data_hash,
             creator_hash,
             asset["leaf_id"],
             asset["leaf_id"],
             proof_addresses,
             recent_blockhash,
             owner_keypair
           ),
           # Send the transaction
           {:ok, signature} <- SolanaRpc.send_transaction(client, tx) do
        {:ok, signature}
      else
        {:error, reason} ->
          {:error, %Error{
            type: :transaction_error,
            message: "Failed to transfer compressed NFT",
            details: reason
          }}
      end
    end

    # Helper functions for safely calling Native functions
    defp safe_generate_keypair do
      {:ok, Native.generate_keypair()}
    rescue
      e -> {:error, "Failed to generate keypair: #{inspect(e)}"}
    end

    defp safe_create_tree_config_tx(payer_keypair, merkle_tree_keypair, max_depth, max_buffer_size, recent_blockhash, public, lamports, account_size) do
      try do
        tx = Native.create_tree_config_ix(
          payer_keypair,
          merkle_tree_keypair,
          max_depth,
          max_buffer_size,
          recent_blockhash,
          public,
          lamports,
          account_size
        )
        {:ok, tx}
      rescue
        e -> {:error, "Failed to create tree config transaction: #{inspect(e)}"}
      end
    end

    defp safe_mint_v1_tx(tree_authority, leaf_owner, leaf_delegate, merkle_tree, payer, metadata_args, recent_blockhash) do
      try do
        tx = Native.mint_v1_ix(
          tree_authority,
          leaf_owner,
          leaf_delegate,
          merkle_tree,
          payer,
          metadata_args,
          recent_blockhash
        )
        {:ok, tx}
      rescue
        e -> {:error, "Failed to create mint transaction: #{inspect(e)}"}
      end
    end

    defp safe_mint_to_collection_tx(tree_authority, leaf_owner, leaf_delegate, merkle_tree, payer,
                                   collection_authority, collection_mint, collection_metadata,
                                   collection_master_edition, metadata_args, recent_blockhash) do
      try do
        tx = Native.mint_to_collection_v1_ix(
          tree_authority,
          leaf_owner,
          leaf_delegate,
          merkle_tree,
          payer,
          collection_authority,
          collection_mint,
          collection_metadata,
          collection_master_edition,
          metadata_args,
          recent_blockhash
        )
        {:ok, tx}
      rescue
        e -> {:error, "Failed to create mint to collection transaction: #{inspect(e)}"}
      end
    end

    defp safe_transfer_tx(tree_authority, leaf_owner, leaf_delegate, new_leaf_owner, merkle_tree,
                         root, data_hash, creator_hash, nonce, index, proof_addresses,
                         recent_blockhash, payer) do
      try do
        tx = Native.transfer_ix(
          tree_authority,
          leaf_owner,
          leaf_delegate,
          new_leaf_owner,
          merkle_tree,
          root,
          creator_hash,
          data_hash,
          nonce,
          index,
          proof_addresses,
          recent_blockhash,
          payer
        )
        {:ok, tx}
      rescue
        e -> {:error, "Failed to create transfer transaction: #{inspect(e)}"}
      end
    end

    @doc """
    Decode a base58 string to binary
    """
    def decode_base58(string) do
      try do
        {:ok, Base58.decode(string)}
      rescue
        _ -> {:error, "Failed to decode base58 string"}
      end
    end
end
