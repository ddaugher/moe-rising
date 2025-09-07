defmodule MoeRising.Experts.Writing do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Writing"

  @impl true
  def description(), do: "Great at tone, structure, and clear explanation."

  @impl true
  def call(prompt, _opts) do
    MoeRising.Logging.log(
      "Writing",
      "Starting writing expert",
      "prompt length: #{String.length(prompt)}"
    )

    sys =
      "You are a precise technical writer. Explain clearly, add structure, and avoid code unless asked."

    # Start async LLM call
    task = Task.async(fn -> LLMClient.chat!(sys, prompt) end)

    # Send periodic activity messages while waiting
    messages = [
      "Setting up the Writing expert workshop...",
      "Gathering #{Enum.random(5..20)} writing templates...",
      "Calibrating tone and style parameters...",
      "Crafting response structure and flow...",
      "Polishing each sentence for clarity...",
      "Quality checking #{Enum.random(2..5)} times...",
      "Packaging final Writing response...",
      "Ready for expert mixture delivery!"
    ]

    # Start progress messages concurrently with LLM call
    progress_task = Task.async(fn ->
      Enum.each(messages, fn msg ->
        MoeRising.Logging.log("Writing", "Status", msg)
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
        MoeRising.Logging.log("Writing", "LLM call timed out after 60s")
        raise "LLM call timed out"
    end

    # Cancel progress task since we got the result
    Task.shutdown(progress_task, :brutal_kill)

    MoeRising.Logging.log(
      "Writing",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens}}
  end
end
