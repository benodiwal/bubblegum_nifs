# BubblegumNifs

Elixir interface for Metaplex Bubblegum compressed NFTs on Solana. This library provides functions to create, mint, and transfer compressed NFTs using the Metaplex Bubblegum program.

# Overview

Compressed NFTs are a space-efficient way to store NFTs on the Solana blockchain. This library provides an Elixir interface to interact with the Metaplex Bubblegum program via Rustler NIFs (Native Implemented Functions).

The library consists of several modules:

- `BubblegumNifs` - Main module with high-level functions for compressed NFT operations
- `BubblegumNifs.Native` - Native implemented functions via Rustler
- `BubblegumNifs.SolanaRpc` - HTTP client for Solana RPC calls
- Several structs representing Solana and Metaplex data structures

# Installation

Add `bubblegum_nifs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bubblegum_nifs, "~> 0.1.0"}
  ]
end
```

# Usage

# Setting up a connection
```elixir
# Create a Solana RPC client
rpc_url = "https://api.mainnet-beta.solana.com"
client = BubblegumNifs.SolanaRpc.new(rpc_url)

# Generate a new keypair
keypair = BubblegumNifs.Native.generate_keypair()
```

# Creating a Merkle Tree
Before minting compressed NFTs, you need to create a Merkle tree to store them:

```elixir
# Create a new Merkle tree with default parameters
{:ok, tree_signature} = BubblegumNifs.create_tree(
  "https://api.mainnet-beta.solana.com",
  payer_keypair,
  14,  # max_depth
  64   # max_buffer_size
)

# The tree_signature is the transaction signature for the tree creation
```

# Minting a Compressed NFT
```elixir
# Create metadata for the NFT
metadata = %BubblegumNifs.MetadataArgs{
  name: "My Compressed NFT",
  symbol: "CNFT",
  uri: "https://arweave.net/metadata.json",
  seller_fee_basis_points: 500,  # 5%
  primary_sale_happened: false,
  is_mutable: true,
  creators: [
    %BubblegumNifs.Creator{
      address: payer_keypair.pubkey,
      verified: true,
      share: 100
    }
  ],
  collection: nil,
  uses: nil
}

# Mint the NFT
{:ok, mint_signature} = BubblegumNifs.mint_compressed_nft(
  "https://api.mainnet-beta.solana.com",
  payer_keypair,
  tree_pubkey,
  recipient_pubkey,
  metadata
)
```

# Minting to a Collection
```elixir
# Mint an NFT to a collection
{:ok, collection_mint_signature} = BubblegumNifs.mint_to_collection(
  "https://api.mainnet-beta.solana.com",
  payer_keypair,
  tree_pubkey,
  recipient_pubkey,
  collection_mint_pubkey,
  collection_authority_keypair,
  metadata
)
```

# Transferring a Compressed NFT
```elixir
# Transfer a compressed NFT
{:ok, transfer_signature} = BubblegumNifs.transfer_compressed_nft(
  "https://api.mainnet-beta.solana.com",
  owner_keypair,
  new_owner_pubkey,
  tree_pubkey,
  root_hash,
  data_hash,
  creator_hash,
  nonce,
  index
)
```

# Module Documentation

# BubblegumNifs
The main module providing high-level functions for compressed NFT operations.

# Functions
`create_tree/4`

```elixir
@spec create_tree(
  rpc_url(),
  keypair(),
  non_neg_integer(),
  non_neg_integer()
) :: {:ok, String.t()} | {:error, any()}
```
Initializes a compressed NFT tree on the Solana blockchain.

Parameters:
- `rpc_url` - URL of the Solana RPC endpoint
- `payer_keypair` - Keypair of the payer account
- `max_depth` - Maximum depth of the Merkle tree (default: 14)
- `max_buffer_size` - Maximum buffer size (default: 64)

Returns:
- `{:ok, signature}` on success
- `{:error, reason}` on failure


`mint_compressed_nft/5`
```elixir
@spec mint_compressed_nft(
  rpc_url(),
  keypair(),
  pubkey(),
  pubkey(),
  metadata()
) :: {:ok, String.t()} | {:error, any()}
```
Mints a new compressed NFT.

Parameters:
- `rpc_url` - URL of the Solana RPC endpoint
- `payer_keypair` - Keypair of the payer account
- `tree_pubkey` - Public key of the Merkle tree
- `recipient_pubkey` - Public key of the recipient
- `metadata` - Metadata for the NFT

Returns:
- `{:ok, signature}` on success
- `{:error, reason}` on failure
