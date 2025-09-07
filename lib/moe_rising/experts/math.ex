defmodule MoeRising.Experts.Math do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Math"

  @impl true
  def description(), do: "Reasoning and quantitative analysis; show steps."

  @impl true
  def call(prompt, _opts) do
    MoeRising.Logging.log(
      "Math",
      "Starting math expert",
      "prompt length: #{String.length(prompt)}"
    )

    sys = "You are a careful math tutor. Solve step by step. If ambiguous, state assumptions."

    # Start async LLM call
    task = Task.async(fn -> LLMClient.chat!(sys, prompt) end)


    # Wait for LLM result with timeout
    result = try do
      case Task.await(task, 60_000) do
        %{content: out, tokens: t} -> %{content: out, tokens: t}
      end
    catch
      :exit, _ ->
        MoeRising.Logging.log("Math", "LLM call timed out after 60s")
        raise "LLM call timed out"
    end


    MoeRising.Logging.log(
      "Math",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens}}
  end
end
