defmodule MoeRising.Experts.Generic do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Generic"

  @impl true
  def description(), do: "General purpose assistant for any type of query."

  @impl true
  def call(prompt, _opts) do
    MoeRising.Logging.log(
      "Generic",
      "Starting generic expert",
      "prompt length: #{String.length(prompt)}"
    )

    # No system prompt - just send the raw prompt directly
    # Start async LLM call
    task = Task.async(fn -> LLMClient.chat!("", prompt) end)

    # Wait for LLM result with timeout
    result = try do
      case Task.await(task, 60_000) do
        %{content: out, tokens: t} -> %{content: out, tokens: t}
      end
    catch
      :exit, _ ->
        MoeRising.Logging.log("Generic", "LLM call timed out after 60s")
        raise "LLM call timed out"
    end

    MoeRising.Logging.log(
      "Generic",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens}}
  end
end
