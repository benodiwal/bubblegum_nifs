defmodule BubblegumNifs.MerkleTree do
  use Bitwise

  @doc """
  Calculates the size of a Merkle Tree based on max_depth, max_buffer_size, and canopy_depth.

  Args:
    max_depth (integer): Maximum depth of the tree
    max_buffer_size (integer): Maximum buffer size
    canopy_depth (integer): Depth of the canopy (defaults to 0)

  Returns:
    integer: Total size of the Merkle Tree in bytes
  """
  def get_merkle_tree_size(max_depth, max_buffer_size, canopy_depth \\ 0) do
    # Anchor discriminator
    discriminator_size = 8
    # ConcurrentMerkleTreeHeader
    header_size = 54
    # ChangeLog entries
    changelog_size = max_buffer_size * 72
    # Nodes (2^max_depth * 32 bytes)
    tree_size = (1 <<< max_depth) * 32
    canopy_size = calculate_canopy_size(canopy_depth)

    discriminator_size + header_size + changelog_size + tree_size + canopy_size
  end

  # Private helper functions

  # defp get_tree_size(max_depth, max_buffer_size) do
  #   # In the TS version, this comes from getConcurrentMerkleTreeSerializer().fixedSize
  #   # We'll implement a basic calculation - adjust this based on your actual tree structure
  #   # Base size per node (assuming 32 bytes like public keys)
  #   base_size = 32
  #   # Assuming 8 bytes per buffer entry
  #   buffer_size = 8 * max_buffer_size
  #   depth_factor = :math.pow(2, max_depth) |> round()

  #   base_size * depth_factor + buffer_size
  # end

  defp calculate_canopy_size(canopy_depth) do
      if canopy_depth == 0 do
        0
      else
        node_size = 32
        canopy_nodes = max((1 <<< (canopy_depth + 1)) - 2, 0)
        node_size * canopy_nodes
      end
    end

  # defp calculate_canopy_nodes(canopy_depth) do
  #   # Bitwise left shift (1 << (canopy_depth + 1)) - 2
  #   shift_amount = canopy_depth + 1
  #   (1 <<< shift_amount) - 2
  # end
end
