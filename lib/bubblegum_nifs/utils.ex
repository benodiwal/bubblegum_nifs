defmodule BubblegumNifs.KeypairInfo do
  @moduledoc """
  Represents a Solana keypair with its public key and secret bytes
  """
  @type t :: %__MODULE__{
    pubkey: String.t(),
    secret: binary()
  }
  defstruct [:pubkey, :secret]
end

defmodule BubblegumNifs.Creator do
  @moduledoc """
  Represents a creator of an NFT
  """
  defstruct [:address, :verified, :share]
end

defmodule BubblegumNifs.Collection do
  @moduledoc """
  Represents a collection NFT information
  """
  defstruct [:verified, :key]
end

defmodule BubblegumNifs.Uses do
  @moduledoc """
  Represents NFT uses information
  """
  defstruct [:use_method, :remaining, :total]
end

defmodule BubblegumNifs.MetadataArgs do
  @moduledoc """
  Represents the metadata for a compressed NFT
  """
  @type t :: %__MODULE__{
    name: String.t(),
    symbol: String.t(),
    uri: String.t(),
    seller_fee_basis_points: non_neg_integer(),
    primary_sale_happened: boolean(),
    is_mutable: boolean(),
    edition_nonce: non_neg_integer() | nil,
    creators: [BubblegumNifs.Creator.t()],
    collection: BubblegumNifs.Collection.t() | nil,
    uses: BubblegumNifs.Uses.t() | nil
  }
  defstruct [
    :name,
    :symbol,
    :uri,
    :seller_fee_basis_points,
    :primary_sale_happened,
    :is_mutable,
    :edition_nonce,
    :creators,
    :collection,
    :uses
  ]
end

defmodule BubblegumNifs.Transaction do
  @moduledoc """
  Struct representing a Solana transaction
  """
  defstruct [:message, :signatures]
end
