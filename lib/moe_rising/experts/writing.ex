defmodule MoeRising.Experts.Writing do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Writing"

  @impl true
  def description(), do: "Great at tone, structure, and clear explanation."

  @impl true
  def call(prompt, _opts) do
    sys =
      "You are a precise technical writer. Explain clearly, add structure, and avoid code unless asked."

    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)
    {:ok, %{output: out, tokens: t}}
  end
end
