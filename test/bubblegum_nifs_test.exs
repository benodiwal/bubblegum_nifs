defmodule BubblegumNifsTest do
  use ExUnit.Case
  alias BubblegumNifs.Native
  alias BubblegumNifs.MetadataArgs
  alias BubblegumNifs.Creator
  alias BubblegumNifs.Collection

  @devnet_url "https://api.devnet.solana.com"

  def create_test_metadata(payer_pubkey) do
    %MetadataArgs{
      name: "Test NFT",
      symbol: "TEST",
      uri: "https://arweave.net/your-metadata",
      seller_fee_basis_points: 500,
      primary_sale_happened: false,
      is_mutable: true,
      edition_nonce: nil,
      creators: [
        %Creator{
          address: payer_pubkey,  # Creator address
          verified: true,
          share: 100
        }
      ],
      collection: nil,
      uses: nil
    }
  end

  test "complete compressed NFT flow" do
    # Generate a payer keypair
    payer_keypair = Native.generate_keypair()

    # Create tree
    {:ok, create_response} = BubblegumNifs.create_tree(
      @devnet_url,
      payer_keypair,
      14,  # max_depth
      64   # max_buffer_size
    )

    # Store the tree pubkey from create_response
    tree_pubkey = create_response["result"]

    # Create metadata for minting
    metadata = create_test_metadata(payer_keypair.pubkey)

    # Mint compressed NFT
    {:ok, mint_response} = BubblegumNifs.mint_compressed_nft(
      @devnet_url,
      payer_keypair,
      tree_pubkey,
      payer_keypair.pubkey,  # recipient is same as payer for test
      metadata
    )

    # Generate a new keypair for the recipient
    recipient_keypair = Native.generate_keypair()

    # Get NFT data from an indexer (this is a placeholder - you need to implement this)
    {:ok, nft_data} = get_nft_data_from_indexer(mint_response["result"])

    # Transfer the NFT
    {:ok, transfer_response} = BubblegumNifs.transfer_compressed_nft(
      @devnet_url,
      payer_keypair,
      recipient_keypair.pubkey,
      tree_pubkey,
      nft_data.root_hash,
      nft_data.data_hash,
      nft_data.creator_hash,
      nft_data.nonce,
      nft_data.index
    )

    assert transfer_response["result"] != nil
  end

  # Placeholder function - you need to implement this based on your indexer
  defp get_nft_data_from_indexer(signature) do
    # This should query your chosen indexer (e.g., Helius) to get the NFT data
    # For now, we'll return mock data
    {:ok, %{
      root_hash: <<0::256>>,      # 32 bytes of zeros
      data_hash: <<1::256>>,      # 32 bytes of ones
      creator_hash: <<2::256>>,    # 32 bytes of twos
      nonce: 0,
      index: 0
    }}
  end
end
