defmodule MoeRising.Router do
  alias MoeRising.Gate
  alias MoeRising.Experts.{Writing, Code, Math, DataViz}

  @experts %{
    "Writing" => Writing,
    "Code" => Code,
    "Math" => Math,
    "DataViz" => DataViz
  }

  @default_top_k 2

  def route(prompt, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, @default_top_k)
    gate = Gate.score(prompt)

    chosen =
      gate.ranked
      |> Enum.take(top_k)
      |> Enum.map(fn {name, p} -> {name, p, Map.fetch!(@experts, name)} end)

    results =
      chosen
      |> Task.async_stream(
        fn {name, prob, mod} ->
          case mod.call(prompt, []) do
            {:ok, %{output: out, tokens: t}} -> %{name: name, prob: prob, output: out, tokens: t}
            {:error, reason} -> %{name: name, prob: prob, output: inspect(reason), tokens: 0}
          end
        end,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    %{
      gate: gate,
      chosen: chosen |> Enum.map(fn {n, p, _} -> {n, p} end),
      results: results,
      aggregate: aggregate(prompt, results)
    }
  end

  # Simple aggregator: pick highest gate prob; if multiple, prefer longer output
  defp aggregate(_prompt, []), do: %{strategy: :none, output: ""}

  defp aggregate(_prompt, results) do
    best =
      results
      |> Enum.sort_by(fn r -> {r.prob, String.length(r.output)} end, :desc)
      |> hd()

    %{strategy: :gate_rank, output: best.output, from: best.name}
  end
end
