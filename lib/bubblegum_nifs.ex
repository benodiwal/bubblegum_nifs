defmodule BubblegumNifs do
    @moduledoc """
    Elixir interface for Metaplex Bubblegum compressed NFTs
    """
    alias BubblegumNifs.Native
    alias BubblegumNifs.Error
    alias BubblegumNifs.SolanaRpc
    alias BubblegumNifs.MerkleTree
    require Logger

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
            account_size = MerkleTree.get_merkle_tree_size(max_depth, max_buffer_size),
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
