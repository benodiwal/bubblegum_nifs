defmodule BubblegumNifs do
    @moduledoc """
    Elixir interface for Metaplex Bubblegum compressed NFTs
    """
    alias BubblegumNifs.Native

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

        @doc """
        Sends a transaction
        """
        def send_transaction(client, %BubblegumNifs.Transaction{message: message, signatures: signatures}) do
          tx_data = message ++ List.flatten(signatures)
          encoded_tx = Base.encode64(IO.iodata_to_binary(tx_data))

          response = post(client, "", %{
            jsonrpc: "2.0",
            id: 1,
            method: "sendTransaction",
            params: [encoded_tx, %{encoding: "base64", preflightCommitment: "confirmed"}]
          })

          case response do
            {:ok, %{status: 200, body: body}} ->
              if body["result"] do
                {:ok, body["result"]}
              else
                {:error, body["error"]}
              end
            error ->
              {:error, error}
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
    end

    @type rpc_url :: String.t()
    @type keypair :: BubblegumNifs.KeypairInfo.t()
    @type pubkey :: String.t()
    @type metadata :: BubblegumNifs.MetadataArgs.t()
    @type hash :: binary()
    @type nonce :: non_neg_integer()
    @type index :: non_neg_integer()

    @spec create_tree(
      rpc_url(),
      keypair(),
      non_neg_integer(),
      non_neg_integer()
    ) :: {:ok, String.t()} | {:error, any()}
    @doc """
    Initializes a compressed NFT tree
    """
    def create_tree(rpc_url, payer_keypair, max_depth \\ 14, max_buffer_size \\ 64) do
        client = SolanaRpc.new(rpc_url)
        tree_keypair = Native.generate_keypair()

        # Recent Blockhash
        {:ok, recent_blockhash} = SolanaRpc.get_recent_blockhash(client)

        # Instruction
        create_ix = Native.create_tree_config_ix(payer_keypair, tree_keypair.pubkey, max_depth, max_buffer_size)

        # Transaction
        tx = Native.create_transaction(recent_blockhash, [create_ix], [payer_keypair])

        SolanaRpc.send_transaction(client, tx)
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
        client = SolanaRpc.new(rpc_url)
        tree_authority = Native.get_tree_authority_pda_address(tree_pubkey)

        # Recent BlockHash
        {:ok, recent_blockhash} = SolanaRpc.get_recent_blockhash(client)

        # Instruction
        mint_ix = Native.mint_v1_ix(tree_authority, recipient_pubkey, recipient_pubkey, tree_pubkey, payer_keypair.pubkey, metadata)

        # Transaction
        tx = Native.create_transaction(recent_blockhash, [mint_ix], [payer_keypair])

        SolanaRpc.send_transaction(client, tx)
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
      client = SolanaRpc.new(rpc_url)
      tree_authority = Native.get_tree_authority_pda_address(tree_pubkey)

      # Recent blockhash
      {:ok, recent_blockhash} = SolanaRpc.get_recent_blockhash(client)

      # Instruction
      mint_ix = Native.mint_to_collection_v1_ix(
        tree_authority,
        recipient_pubkey,
        recipient_pubkey, # delegate is same as owner initially
        tree_pubkey,
        payer_keypair.pubkey,
        collection_authority_keypair.pubkey,
        collection_mint,
        "", # Empty string for PDA derivation in Rust
        "", # Empty string for PDA derivation in Rust
        metadata
      )

      # Transaction
      tx = Native.create_transaction(recent_blockhash, [mint_ix], [payer_keypair])

      SolanaRpc.send_transaction(client, tx)
    end

    @spec transfer_compressed_nft(
      rpc_url(),
      keypair(),
      pubkey(),
      pubkey(),
      hash(),
      hash(),
      hash(),
      nonce(),
      index()
    ) :: {:ok, String.t()} | {:error, any()}
    @doc """
    Transfers a compressed NFT
    """
    def transfer_compressed_nft(rpc_url, owner_keypair, new_owner_pubkey, tree_pubkey,
                                root, data_hash, creator_hash, nonce, index) do
      client = SolanaRpc.new(rpc_url)
      tree_authority = Native.get_tree_authority_pda_address(tree_pubkey)

      # Recent blockhash
      {:ok, recent_blockhash} = SolanaRpc.get_recent_blockhash(client)

      # Instruction
      transfer_ix = Native.transfer_ix(
        tree_authority,
        owner_keypair.pubkey,
        owner_keypair.pubkey, # delegate is same as owner
        new_owner_pubkey,
        tree_pubkey,
        root,
        creator_hash,
        data_hash,
        nonce,
        index
      )

      # Transaction
      tx = Native.create_transaction(recent_blockhash, [transfer_ix], [owner_keypair])

      SolanaRpc.send_transaction(client, tx)
    end
end
