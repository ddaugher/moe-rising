defmodule MoeRising.Experts.Code do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Code"

  @impl true
  def description(), do: "Excellent at Elixir/Phoenix code and debugging."

  @impl true
  def call(prompt, _opts) do
    sys =
      "You are an expert Elixir/Phoenix engineer. Prefer runnable snippets and short explanations."

    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)
    {:ok, %{output: out, tokens: t}}
  end
end
