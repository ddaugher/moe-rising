defmodule MoeRising.Experts.Writing do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Writing"

  @impl true
  def description(), do: "Great at tone, structure, and clear explanation."

  @impl true
  def call(prompt, opts) do
    log_pid = Keyword.get(opts, :log_pid)

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "Writing",
        "Starting writing expert",
        "prompt length: #{String.length(prompt)}"
      )
    end

    sys =
      "You are a precise technical writer. Explain clearly, add structure, and avoid code unless asked."

    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "Writing",
        "Completed",
        "tokens: #{t}, output length: #{String.length(out)}"
      )
    end

    {:ok, %{output: out, tokens: t}}
  end
end
