defmodule MoeRising.Expert do
  @moduledoc """
  Behaviour for MoE experts.
  """
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback call(prompt :: String.t(), opts :: Keyword.t()) ::
              {:ok, %{output: String.t(), tokens: non_neg_integer}} | {:error, term}
end
