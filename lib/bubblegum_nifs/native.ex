defmodule BubblegumNifs.Native do
  @moduledoc """
  Native Implemented Functions for Metaplex Bubblegum compressed NFTs operations
  """
  use Rustler, otp_app: :bubblegum_nifs, crate: "bubblegum_nifs"

  @spec generate_keypair() :: BubblegumNifs.KeypairResult.t()
  def generate_keypair(), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_tree_config_ix(
          BubblegumNifs.KeypairInfo.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: binary()
  def create_tree_config_ix(_payer_info, _merkle_tree, _max_depth, _max_buffer_size), do: :erlang.nif_error(:nif_not_loaded)

  @spec mint_v1_ix(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          BubblegumNifs.MetadataArgs.t()
        ) :: binary()
  def mint_v1_ix(_tree_authority, _leaf_owner, _leaf_delegate, _merkle_tree, _payer, _metadata_args), do: :erlang.nif_error(:nif_not_loaded)

  @spec mint_to_collection_v1_ix(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          BubblegumNifs.MetadataArgs.t()
        ) :: binary()
  def mint_to_collection_v1_ix(_tree_authority, _leaf_owner, _leaf_delegate, _merkle_tree, _payer, _collection_authority, _collection_mint, _collection_metadata, _collection_master_edition, _metadata_args), do: :erlang.nif_error(:nif_not_loaded)

  @spec transfer_ix(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          binary(),
          binary(),
          binary(),
          non_neg_integer(),
          non_neg_integer()
        ) :: binary()
  def transfer_ix(_tree_authority, _leaf_owner, _leaf_delegate, _new_leaf_owner, _merkle_tree, _root_hash, _creator_hash, _data_hash, _nonce, _index), do: :erlang.nif_error(:nif_not_loaded)

  @spec create_transaction(
    String.t(),
    list(binary()),
    list(BubblegumNifs.KeypairInfo.t())
  ) :: BubblegumNifs.Transaction.t()
  def create_transaction(_recent_blockhash, _instructions, _signers), do: :erlang.nif_error(:nif_not_loaded)


  @spec get_tree_authority_pda_address(String.t()) :: String.t()
  def get_tree_authority_pda_address(_merkle_tree), do: :erlang.nif_error(:nif_not_loaded)
end
