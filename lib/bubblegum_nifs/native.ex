defmodule BubblegumNifs.Native do
  @moduledoc """
  Native Implemented Functions for Metaplex Bubblegum compressed NFTs operations
  """
  use Rustler, otp_app: :bubblegum_nifs, crate: "bubblegum_nifs"

  @spec generate_keypair() :: BubblegumNifs.KeyPairInfo.t()
  def generate_keypair(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates an instruction to configure a new compressed NFT tree.

  ## Parameters:
  - payer_info: The keypair that will fund the transaction
  - merkle_tree: The public key of the merkle tree (as string)
  - max_depth: The maximum depth of the merkle tree
  - max_buffer_size: The maximum buffer size for the merkle tree
  - recent_blockhash: The recent blockhash to use for the transaction
  - public: Whether the tree should be public

  ## Returns:
  A serialized transaction
  """
  @spec create_tree_config_ix(
          BubblegumNifs.KeypairInfo.t(),  # payer_info
          String.t(),                     # merkle_tree
          non_neg_integer(),              # max_depth
          non_neg_integer(),              # max_buffer_size
          String.t(),                     # recent_blockhash
          boolean(),                      # public
          integer(),                      # lamports
          integer()                       # account_size
        ) :: binary()
  def create_tree_config_ix(_payer_info, _merkle_tree, _max_depth, _max_buffer_size, _recent_blockhash, _public, _lamports, _account_size), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates an instruction to mint a compressed NFT (version 1).

  ## Parameters:
  - tree_authority: The public key of the tree authority (as string)
  - leaf_owner: The public key of the leaf owner (as string)
  - leaf_delegate: The public key of the leaf delegate (as string)
  - merkle_tree: The public key of the merkle tree (as string)
  - payer: Keypair info for the transaction payer
  - metadata_args: The metadata for the NFT
  - recent_blockhash: The recent blockhash to use for the transaction

  ## Returns:
  A serialized transaction
  """
  @spec mint_v1_ix(
          String.t(),                       # tree_authority
          String.t(),                       # leaf_owner
          String.t(),                       # leaf_delegate
          String.t(),                       # merkle_tree
          BubblegumNifs.KeypairInfo.t(),    # payer
          BubblegumNifs.MetadataArgs.t(),   # metadata_args
          String.t()                        # recent_blockhash
        ) :: binary()
  def mint_v1_ix(_tree_authority, _leaf_owner, _leaf_delegate, _merkle_tree, _payer, _metadata_args, _recent_blockhash), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates an instruction to mint a compressed NFT to a collection.

  ## Parameters:
  - tree_authority: The public key of the tree authority (as string)
  - leaf_owner: The public key of the leaf owner (as string)
  - leaf_delegate: The public key of the leaf delegate (as string)
  - merkle_tree: The public key of the merkle tree (as string)
  - payer: Keypair info for the transaction payer
  - collection_authority: The public key of the collection authority (as string)
  - collection_mint: The public key of the collection mint (as string)
  - collection_metadata: The public key of the collection metadata (as string)
  - collection_master_edition: The public key of the collection master edition (as string)
  - metadata_args: The metadata for the NFT
  - recent_blockhash: The recent blockhash to use for the transaction

  ## Returns:
  A serialized transaction
  """
  @spec mint_to_collection_v1_ix(
          String.t(),                      # tree_authority
          String.t(),                      # leaf_owner
          String.t(),                      # leaf_delegate
          String.t(),                      # merkle_tree
          BubblegumNifs.KeypairInfo.t(),   # payer
          String.t(),                      # collection_authority
          String.t(),                      # collection_mint
          String.t(),                      # collection_metadata
          String.t(),                      # collection_master_edition
          BubblegumNifs.MetadataArgs.t(),  # metadata_args
          String.t()                       # recent_blockhash
        ) :: binary()
  def mint_to_collection_v1_ix(_tree_authority, _leaf_owner, _leaf_delegate, _merkle_tree, _payer, _collection_authority, _collection_mint, _collection_metadata, _collection_master_edition, _metadata_args, _recent_blockhash), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates an instruction to transfer a compressed NFT.

  ## Parameters:
  - tree_authority: The public key of the tree authority (as string)
  - leaf_owner: The public key of the current leaf owner (as string)
  - leaf_delegate: The public key of the leaf delegate (as string)
  - new_leaf_owner: The public key of the new leaf owner (as string)
  - merkle_tree: The public key of the merkle tree (as string)
  - root: The root hash of the merkle tree (as binary)
  - data_hash: The data hash of the asset (as binary)
  - creator_hash: The creator hash of the asset (as binary)
  - nonce: The nonce (leaf_id) of the asset
  - index: The index (leaf_id as u32) of the asset
  - proof_addresses: List of public keys in the merkle proof (as strings)
  - recent_blockhash: The recent blockhash to use for the transaction
  - payer: Keypair info for the transaction payer

  ## Returns:
  A serialized transaction
  """
  @spec transfer_ix(
          String.t(),                    # tree_authority
          String.t(),                    # leaf_owner
          String.t(),                    # leaf_delegate
          String.t(),                    # new_leaf_owner
          String.t(),                    # merkle_tree
          binary(),                      # root
          binary(),                      # data_hash
          binary(),                      # creator_hash
          non_neg_integer(),             # nonce
          non_neg_integer(),             # index
          list(String.t()),              # proof_addresses
          String.t(),                    # recent_blockhash
          BubblegumNifs.KeypairInfo.t()  # payer
        ) :: binary()
  def transfer_ix(
    _tree_authority,
    _leaf_owner,
    _leaf_delegate,
    _new_leaf_owner,
    _merkle_tree,
    _root,
    _data_hash,
    _creator_hash,
    _nonce,
    _index,
    _proof_addresses,
    _recent_blockhash,
    _payer
  ), do: :erlang.nif_error(:nif_not_loaded)

  @spec get_tree_authority_pda_address(String.t()) :: String.t()
  def get_tree_authority_pda_address(_merkle_tree), do: :erlang.nif_error(:nif_not_loaded)
end
