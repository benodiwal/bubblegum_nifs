# BubblegumNifs

## Introduction

BubblegumNifs is an Elixir library that provides a native interface to Solana's Metaplex Bubblegum program for working with compressed NFTs. Compressed NFTs allow for significant cost savings and improved scalability compared to traditional Solana NFTs by utilizing state compression techniques.

This library provides Elixir developers with the ability to:
- Create merkle trees for storing compressed NFTs
- Mint compressed NFTs as standalone assets or as part of collections
- Transfer compressed NFTs between wallets

The implementation uses Rustler to create Native Implemented Functions (NIFs) that directly interact with Solana's programs through Rust, providing efficient and type-safe operations.

## Installation

Add `bubblegum_nifs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bubblegum_nifs, "~> 0.1.0"}
  ]
end
```

## Architecture

BubblegumNifs follows a layered architecture:

1. **Elixir Interface Layer**: High-level, developer-friendly functions
2. **Elixir-Rust Bridge**: Rustler NIF functions that communicate with Rust code
3. **Rust Core Layer**: Direct interaction with Solana programs through native Rust
4. **Solana RPC Layer**: Communication with Solana blockchain

## Data Structures

### KeyPairInfo

Represents a Solana keypair:

```elixir
%BubblegumNifs.KeyPairInfo{
  pubkey: String.t(),  # Base58 encoded public key
  secret: binary()     # Raw secret key bytes
}
```

### MetadataArgs

NFT metadata for minting:

```elixir
%BubblegumNifs.MetadataArgs{
  name: String.t(),                     # NFT name
  symbol: String.t(),                   # NFT symbol
  uri: String.t(),                      # JSON metadata URI
  seller_fee_basis_points: integer(),   # Royalty amount (e.g., 500 = 5%)
  primary_sale_happened: boolean(),     # Whether primary sale occurred
  is_mutable: boolean(),                # Whether metadata can be changed
  edition_nonce: integer() | nil,       # Edition nonce if applicable
  creators: [Creator.t()],              # List of creators
  collection: Collection.t() | nil,     # Optional collection details
  uses: Uses.t() | nil                  # Optional uses configuration
}
```

### Creator

Represents an NFT creator:

```elixir
%BubblegumNifs.Creator{
  address: String.t(),  # Creator's wallet address
  verified: boolean(),  # Whether creator signature is verified
  share: integer()      # Percentage share of royalties (0-100)
}
```

### Collection

Collection information for the NFT:

```elixir
%BubblegumNifs.Collection{
  verified: boolean(),  # Whether collection verification is completed
  key: String.t()       # Collection NFT mint address
}
```

### Uses

Defines how an NFT can be "used" (consumed):

```elixir
%BubblegumNifs.Uses{
  use_method: integer(),   # 0: Burn, 1: Multiple, 2: Single
  remaining: integer(),    # Uses remaining
  total: integer()         # Total allowed uses
}
```

### Transaction

Represents a serialized Solana transaction:

```elixir
%BubblegumNifs.Transaction{
  message: binary(),       # Serialized transaction message
  signatures: [binary()]   # List of transaction signatures
}
```

## Core Functions

### Creating a Merkle Tree

Before minting compressed NFTs, you must create a merkle tree to store them.

```elixir
# Calculate size and rent for a merkle tree
tree_size = BubblegumNifs.MerkleTree.get_merkle_tree_size(max_depth, max_buffer_size)
{:ok, rent} = BubblegumNifs.SolanaRpc.get_mint_rent(client, tree_size)

# Generate a new keypair for the tree
merkle_tree_keypair = BubblegumNifs.Native.generate_keypair()

# Create the tree
{:ok, tx} = BubblegumNifs.Native.create_tree_config_ix(
  payer_keypair,
  merkle_tree_keypair,
  max_depth,
  max_buffer_size,
  recent_blockhash,
  true,  # public
  rent,
  tree_size
)

# Send transaction
{:ok, signature} = BubblegumNifs.SolanaRpc.send_transaction(client, tx)
```

### Minting a Compressed NFT

To mint a new compressed NFT:

```elixir
# Prepare metadata
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

# Get tree authority
tree_authority = BubblegumNifs.Native.get_tree_authority_pda_address(merkle_tree_pubkey)

# Create mint transaction
{:ok, tx} = BubblegumNifs.Native.mint_v1_ix(
  tree_authority,
  recipient_pubkey,
  recipient_pubkey,  # delegate is same as owner initially
  merkle_tree_pubkey,
  payer_keypair,
  metadata,
  recent_blockhash
)

# Send transaction
{:ok, signature} = BubblegumNifs.SolanaRpc.send_transaction(client, tx)
```

### Minting to a Collection

To mint a compressed NFT as part of a collection:

```elixir
# Include collection in metadata
metadata = %BubblegumNifs.MetadataArgs{
  # ... other metadata fields
  collection: %BubblegumNifs.Collection{
    verified: false,  # Will be verified by the transaction
    key: collection_mint_pubkey
  }
}

# Create mint transaction
{:ok, tx} = BubblegumNifs.Native.mint_to_collection_v1_ix(
  tree_authority,
  recipient_pubkey,
  recipient_pubkey,  # delegate is same as owner initially
  merkle_tree_pubkey,
  payer_keypair,
  collection_authority_pubkey,
  collection_mint_pubkey,
  "",  # Empty to derive PDA
  "",  # Empty to derive PDA
  metadata,
  recent_blockhash
)

# Send transaction
{:ok, signature} = BubblegumNifs.SolanaRpc.send_transaction(client, tx)
```

### Transferring a Compressed NFT

Transferring requires merkle proof data from the Digital Asset Standard (DAS) API:

```elixir
# Get asset details and proof
{:ok, asset} = BubblegumNifs.SolanaRpc.get_asset_details(client, asset_id)
{:ok, proof} = BubblegumNifs.SolanaRpc.get_asset_proof(client, asset_id)

# Decode necessary hashes from base58
{:ok, root} = Base58.decode(proof["root"])
{:ok, data_hash} = Base58.decode(asset["data_hash"])
{:ok, creator_hash} = Base58.decode(asset["creator_hash"])

# Create transfer transaction
{:ok, tx} = BubblegumNifs.Native.transfer_ix(
  tree_authority,
  owner_pubkey,
  owner_pubkey,  # delegate is same as owner
  new_owner_pubkey,
  merkle_tree_pubkey,
  root,
  creator_hash,
  data_hash,
  asset["leaf_id"],  # nonce
  asset["leaf_id"],  # index
  proof["proof"],    # List of proof addresses
  recent_blockhash,
  owner_keypair
)

# Send transaction
{:ok, signature} = BubblegumNifs.SolanaRpc.send_transaction(client, tx)
```

## Solana RPC Functions

The library provides a convenient interface to Solana RPC endpoints:

```elixir
# Create a new client
client = BubblegumNifs.SolanaRpc.new("https://api.mainnet-beta.solana.com")

# Get recent blockhash
{:ok, blockhash} = BubblegumNifs.SolanaRpc.get_recent_blockhash(client)

# Get account information
{:ok, account_info} = BubblegumNifs.SolanaRpc.get_account_info(client, pubkey)

# Get compressed asset details (DAS API)
{:ok, asset} = BubblegumNifs.SolanaRpc.get_asset_details(client, asset_id)

# Get merkle proof for asset (DAS API)
{:ok, proof} = BubblegumNifs.SolanaRpc.get_asset_proof(client, asset_id)

# Calculate minimum rent for an account
{:ok, rent} = BubblegumNifs.SolanaRpc.get_mint_rent(client, account_size)
```

## Merkle Tree Size Calculation

The library provides a function to calculate the correct size for a merkle tree account:

```elixir
# Calculate size for a tree with default parameters
size = BubblegumNifs.MerkleTree.get_merkle_tree_size(14, 64)

# Calculate size with custom canopy depth
size = BubblegumNifs.MerkleTree.get_merkle_tree_size(14, 64, 8)
```

## Error Handling

The library uses a standardized error struct:

```elixir
%BubblegumNifs.Error{
  type: :rpc_error | :transaction_error | :instruction_error | :validation_error,
  message: String.t(),
  details: any()
}
```

Examples of error handling:

```elixir
case BubblegumNifs.SolanaRpc.send_transaction(client, tx) do
  {:ok, signature} ->
    IO.puts("Transaction succeeded with signature: #{signature}")

  {:error, %BubblegumNifs.Error{type: :rpc_error, message: msg, details: details}} ->
    IO.puts("RPC error: #{msg}")
    IO.inspect(details)

  {:error, %BubblegumNifs.Error{type: :transaction_error}} ->
    IO.puts("Transaction failed")
end
```

## Performance Considerations

1. **Account Size Calculation**: Correct account size calculation is critical for merkle trees. Undersized accounts will fail, while oversized accounts waste SOL.

2. **Proof Size**: When transferring assets, ensure the merkle proof is correctly retrieved from the DAS API.

3. **Large Tree Depth**: Trees with larger depths can support more NFTs but require more SOL to create.

## Best Practices

1. **Tree Parameters**: For most use cases, `max_depth=14` and `max_buffer_size=64` provide a good balance between cost and capacity.

2. **Public Trees**: Setting `public=true` allows anyone to mint to your tree.

3. **Error Handling**: Always handle errors, especially when interacting with RPC endpoints, as network issues can occur.

4. **URI Standards**: Use standard JSON metadata URIs (preferably on permanent storage like Arweave) for compatibility with marketplaces.

5. **Collection Verification**: When minting to collections, ensure that the collection authority is the correct signer.

## Limitations

1. **Compressed NFTs vs Traditional NFTs**: Compressed NFTs are stored differently from traditional NFTs and may have limited support in some wallets/marketplaces.

2. **RPC Availability**: Operations with compressed NFTs require RPC endpoints that support the Digital Asset Standard (DAS) API.

3. **Transaction Size**: Very deep merkle proofs can approach Solana's transaction size limits.

## Appendix: Common Tree Sizes

| max_depth | max_buffer_size | Approximate Capacity | Approximate Size |
|-----------|-----------------|----------------------|------------------|
| 14        | 64              | ~16k NFTs            | ~12KB            |
| 20        | 256             | ~1M NFTs             | ~48KB            |
| 24        | 1024            | ~16M NFTs            | ~192KB           |
| 30        | 2048            | ~1B NFTs             | ~512KB           |

## Contributing

Contributions to BubblegumNifs are welcome. Please ensure that your code follows the existing style and includes proper documentation.

## License

This library is licensed under the MIT License.
