defmodule MoeRising.Experts.DataViz do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient
  def name(), do: "DataViz"
  def description(), do: "Creates charts and explains visual encodings."

  def call(prompt, opts) do
    log_pid = Keyword.get(opts, :log_pid)

    if log_pid do
      MoeRising.Logging.log(log_pid, "DataViz", "Starting dataviz expert", "prompt length: #{String.length(prompt)}")
    end

    sys =
      "You create precise data visualizations and explain how to build them in Elixir/Phoenix + Vega-Lite."

    %{content: out, tokens: t} = LLMClient.chat!(sys, prompt)

    if log_pid do
      MoeRising.Logging.log(log_pid, "DataViz", "Completed", "tokens: #{t}, output length: #{String.length(out)}")
    end

    {:ok, %{output: out, tokens: t}}
  end
end
