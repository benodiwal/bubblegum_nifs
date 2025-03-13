defmodule BubblegumNifs.Error do
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
