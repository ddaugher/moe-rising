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

    # Send periodic activity messages while waiting
    messages = [
      "Setting up the DataViz expert workshop...",
      "Gathering #{Enum.random(8..25)} visualization patterns...",
      "Calibrating Vega-Lite rendering engines...",
      "Crafting visual encoding strategy...",
      "Polishing each chart and visualization...",
      "Quality checking #{Enum.random(2..5)} times...",
      "Packaging final DataViz response...",
      "Ready for expert mixture delivery!"
    ]

    # Start progress messages concurrently with LLM call
    progress_task = Task.async(fn ->
      Enum.each(messages, fn msg ->
        MoeRising.Logging.log("DataViz", "Status", msg)
        Process.sleep(2000)
      end)
    end)

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

    # Cancel progress task since we got the result
    Task.shutdown(progress_task, :brutal_kill)

    MoeRising.Logging.log(
      "DataViz",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens}}
  end
end
