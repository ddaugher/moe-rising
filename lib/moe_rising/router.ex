defmodule MoeRising.Router do
  alias MoeRising.Gate
  alias MoeRising.LLMClient
  alias MoeRising.Experts.{Writing, Code, Math, DataViz, RAG}

  @experts %{
    "Writing" => Writing,
    "Code" => Code,
    "Math" => Math,
    "DataViz" => DataViz,
    "RAG" => RAG
  }

  @default_top_k 2

  def route(prompt, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, @default_top_k)
    log_pid = Keyword.get(opts, :log_pid)
    gate = Gate.score(prompt)

    chosen =
      gate.ranked
      |> Enum.take(top_k)
      |> Enum.map(fn {name, p} -> {name, p, Map.fetch!(@experts, name)} end)

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "Router",
        "Selected experts: #{Enum.map(chosen, fn {name, _, _} -> name end) |> Enum.join(", ")}"
      )

      MoeRising.Logging.log(log_pid, "Router", "Gate probabilities", gate.ranked)
    end

    results =
      chosen
      |> Task.async_stream(
        fn {name, prob, mod} ->
          if log_pid do
            MoeRising.Logging.log(
              log_pid,
              "Router",
              "Starting expert: #{name} (probability: #{Float.round(prob, 3)})"
            )
          end

          try do
            case mod.call(prompt, log_pid: log_pid) do
              {:ok, %{output: out, tokens: t} = result} ->
                if log_pid do
                  MoeRising.Logging.log(
                    log_pid,
                    "Router",
                    "Completed expert #{name}",
                    "tokens: #{t}, output length: #{String.length(out)}"
                  )

                  if Map.has_key?(result, :sources) do
                    MoeRising.Logging.log(
                      log_pid,
                      "Router",
                      "#{name} sources",
                      "found #{length(result.sources)} sources"
                    )
                  end
                end

                %{
                  name: name,
                  prob: prob,
                  output: out,
                  tokens: t,
                  sources: Map.get(result, :sources)
                }

              {:error, reason} ->
                if log_pid do
                  MoeRising.Logging.log(log_pid, "Router", "Error in #{name}", reason)
                end

                %{name: name, prob: prob, output: "Error: #{inspect(reason)}", tokens: 0}
            end
          rescue
            e ->
              if log_pid do
                MoeRising.Logging.log(log_pid, "Router", "Exception in #{name}", e)
              end

              %{name: name, prob: prob, output: "Exception: #{inspect(e)}", tokens: 0}
          end
        end,
        timeout: 120_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    aggregate_result = aggregate(prompt, results, log_pid)

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "Router",
        "Strategy: #{aggregate_result.strategy}",
        "from: #{aggregate_result.from}"
      )
    end

    %{
      gate: gate,
      chosen: chosen |> Enum.map(fn {n, p, _} -> {n, p} end),
      results: results,
      aggregate: aggregate_result
    }
  end

  # Simple aggregator: pick highest gate prob; if multiple, prefer longer output
  defp aggregate(_prompt, [], _log_pid), do: %{strategy: :none, output: ""}

  # defp aggregate(_prompt, results, _log_pid) do
  #   best =
  #     results
  #     |> Enum.sort_by(fn r -> {r.prob, String.length(r.output)} end, :desc)
  #     |> hd()

  #   %{strategy: :gate_rank, output: best.output, from: best.name}
  # end

  defp aggregate(prompt, results, log_pid) do
    case results do
      [] ->
        MoeRising.Logging.log(log_pid, "Router", "No results")
        %{strategy: :none, output: ""}

      [_] = [only] ->
        MoeRising.Logging.log(log_pid, "Router", "Single result")
        %{strategy: :single, output: only.output, from: only.name}

      _ ->
        MoeRising.Logging.log(log_pid, "Router", "Multiple results")
        sys = "You are a helpful judge. Combine the best parts concisely."

        user =
          "Prompt: #{prompt}\n\nCandidates:\n" <>
            Enum.map_join(results, "\n---\n", fn r ->
              "[#{r.name} p=#{Float.round(r.prob, 4)}]\n#{r.output}"
            end)

        # MoeRising.Logging.log(
        #   log_pid,
        #   "Router",
        #   "Aggregating results",
        #   "prompt: #{prompt}"
        # )

        # MoeRising.Logging.log(
        #   log_pid,
        #   "Router",
        #   "Aggregating results",
        #   "results: #{inspect(results)}"
        # )

        %{content: out, tokens: _t} = LLMClient.chat!(sys, user)

        MoeRising.Logging.log(log_pid, "Router", "Strategy: judge_llm", "output: #{out}")

        %{
          strategy: :judge_llm,
          output: out,
          from: Enum.map(results, & &1.name) |> Enum.join(", ")
        }
    end
  end
end
