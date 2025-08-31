defmodule MoeRising.Router do
  alias MoeRising.Gate
  alias MoeRising.LLMClient
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

  # defp aggregate(_prompt, results) do
  #   best =
  #     results
  #     |> Enum.sort_by(fn r -> {r.prob, String.length(r.output)} end, :desc)
  #     |> hd()

  #   %{strategy: :gate_rank, output: best.output, from: best.name}
  # end

  defp aggregate(prompt, results) do
    case results do
      [] ->
        %{strategy: :none, output: ""}

      [_] = [only] ->
        %{strategy: :single, output: only.output, from: only.name}

      _ ->
        sys = "You are a helpful judge. Combine the best parts concisely."

        user =
          "Prompt: #{prompt}\n\nCandidates:\n" <>
            Enum.map_join(results, "\n---\n", fn r ->
              "[#{r.name} p=#{Float.round(r.prob, 2)}]\n#{r.output}"
            end)

        %{content: out, tokens: _t} = LLMClient.chat!(sys, user)

        %{
          strategy: :judge_llm,
          output: out,
          from: Enum.map(results, & &1.name) |> Enum.join(", ")
        }
    end
  end
end
