defmodule MoeRising.Experts.Code do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient

  @impl true
  def name(), do: "Code"

  @impl true
  def description(), do: "Excellent at Elixir/Phoenix code and debugging."

  @impl true
  def call(prompt, opts) do
    log_pid = Keyword.get(opts, :log_pid)

    if log_pid do
      MoeRising.Logging.log(log_pid, "Code", "Starting code expert", "prompt length: #{String.length(prompt)}")
    end

    sys =
      "You are an expert Elixir/Phoenix engineer. Prefer runnable snippets and short explanations."

    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)

    if log_pid do
      MoeRising.Logging.log(log_pid, "Code", "Completed", "tokens: #{t}, output length: #{String.length(out)}")
    end

    {:ok, %{output: out, tokens: t}}
  end
end
