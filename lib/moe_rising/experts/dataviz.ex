defmodule MoeRising.Experts.DataViz do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient
  def name(), do: "DataViz"
  def description(), do: "Creates charts and explains visual encodings."

  def call(prompt, _opts) do
    sys =
      "You create precise data visualizations and explain how to build them in Elixir/Phoenix + Vega-Lite."

    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)
    {:ok, %{output: out, tokens: t}}
  end
end
