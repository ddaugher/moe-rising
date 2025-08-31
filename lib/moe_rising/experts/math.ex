defmodule MoeRising.Experts.Math do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Math"

  @impl true
  def description(), do: "Reasoning and quantitative analysis; show steps."

  @impl true
  def call(prompt, _opts) do
    sys = "You are a careful math tutor. Solve step by step. If ambiguous, state assumptions."
    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)
    {:ok, %{output: out, tokens: t}}
  end
end
