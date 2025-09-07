defmodule MoeRising.Experts.Code do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Code"

  @impl true
  def description(), do: "Excellent at Elixir/Phoenix code and debugging."

  @impl true
  def call(prompt, _opts) do
    MoeRising.Logging.log(
      "Code",
      "Starting code expert",
      "prompt length: #{String.length(prompt)}"
    )

    sys =
      "You are an expert Elixir/Phoenix engineer. Prefer runnable snippets and short explanations."

    # Start async LLM call
    task = Task.async(fn -> LLMClient.chat!(sys, prompt) end)

    # Send periodic activity messages while waiting
    messages = [
      "Setting up the Code expert workshop...",
      "Gathering #{Enum.random(10..30)} code patterns...",
      "Calibrating Elixir/Phoenix frameworks...",
      "Crafting clean, functional solution...",
      "Polishing each function and module...",
      "Quality checking #{Enum.random(3..7)} times...",
      "Packaging final Code response...",
      "Ready for expert mixture delivery!"
    ]

    # Start progress messages concurrently with LLM call
    progress_task = Task.async(fn ->
      Enum.each(messages, fn msg ->
        MoeRising.Logging.log("Code", "Status", msg)
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
        MoeRising.Logging.log("Code", "LLM call timed out after 60s")
        raise "LLM call timed out"
    end

    # Cancel progress task since we got the result
    Task.shutdown(progress_task, :brutal_kill)

    MoeRising.Logging.log(
      "Code",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens}}
  end
end
