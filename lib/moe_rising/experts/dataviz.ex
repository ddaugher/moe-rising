defmodule MoeRising.Experts.DataViz do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient
  def name(), do: "DataViz"
  def description(), do: "Creates charts and explains visual encodings."

  def call(prompt, _opts) do
    MoeRising.Logging.log(
      "DataViz",
      "Starting dataviz expert",
      "prompt length: #{String.length(prompt)}"
    )

    sys =
      "You create precise data visualizations and explain how to build them in Elixir/Phoenix + Vega-Lite."

    # Start async LLM call
    task = Task.async(fn -> LLMClient.chat!(sys, prompt) end)


    # Wait for LLM result with timeout
    result = try do
      case Task.await(task, 60_000) do
        %{content: out, tokens: t} -> %{content: out, tokens: t}
      end
    catch
      :exit, _ ->
        MoeRising.Logging.log("DataViz", "LLM call timed out after 60s")
        raise "LLM call timed out"
    end


    MoeRising.Logging.log(
      "DataViz",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens}}
  end
end
