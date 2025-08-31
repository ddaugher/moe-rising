defmodule MoeRising.Experts.Math do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Math"

  @impl true
  def description(), do: "Reasoning and quantitative analysis; show steps."

  @impl true
  def call(prompt, opts) do
    log_pid = Keyword.get(opts, :log_pid)

    if log_pid do
      MoeRising.Logging.log(log_pid, "Math", "Starting math expert", "prompt length: #{String.length(prompt)}")
    end

    sys = "You are a careful math tutor. Solve step by step. If ambiguous, state assumptions."
    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)

    if log_pid do
      MoeRising.Logging.log(log_pid, "Math", "Completed", "tokens: #{t}, output length: #{String.length(out)}")
    end

    {:ok, %{output: out, tokens: t}}
  end
end
