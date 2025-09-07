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
    gate = Gate.score(prompt)

    chosen =
      gate.ranked
      |> Enum.take(top_k)
      |> Enum.map(fn {name, p} -> {name, p, Map.fetch!(@experts, name)} end)

    MoeRising.Logging.log(
      "Router",
      "Selected experts: #{Enum.map(chosen, fn {name, _, _} -> name end) |> Enum.join(", ")}"
    )

    MoeRising.Logging.log("Router", "Gate probabilities", gate.ranked)

    results =
      chosen
      |> Task.async_stream(
        fn {name, prob, mod} ->
          MoeRising.Logging.log(
            "Router",
            "Starting expert: #{name} (probability: #{Float.round(prob, 3)})"
          )

          try do
            case mod.call(prompt, log_pid: nil) do
              {:ok, %{output: out, tokens: t} = result} ->
                MoeRising.Logging.log(
                  "Router",
                  "Completed expert #{name}",
                  "tokens: #{t}, output length: #{String.length(out)}"
                )

                if Map.has_key?(result, :sources) do
                  MoeRising.Logging.log(
                    "Router",
                    "#{name} sources",
                    "found #{length(result.sources)} sources"
                  )
                end

                expert_result = %{
                  name: name,
                  prob: prob,
                  output: out,
                  tokens: t,
                  sources: Map.get(result, :sources)
                }

                # Log expert result completion
                MoeRising.Logging.log(
                  "DEBUG",
                  "Completed expert result for #{name}",
                  "tokens: #{t}, output length: #{String.length(out)}"
                )

                expert_result

              {:error, reason} ->
                MoeRising.Logging.log("Router", "Error in #{name}", reason)

                expert_result = %{
                  name: name,
                  prob: prob,
                  output: "Error: #{inspect(reason)}",
                  tokens: 0
                }

                expert_result
            end
          rescue
            e ->
              MoeRising.Logging.log("Router", "Exception in #{name}", e)

              expert_result = %{
                name: name,
                prob: prob,
                output: "Exception: #{inspect(e)}",
                tokens: 0
              }

              expert_result
          end
        end,
        timeout: 120_000
      )
      |> Enum.map(fn {:ok, r} -> r end)

    aggregate_result = aggregate(prompt, results)

    MoeRising.Logging.log(
      "Router",
      "Strategy: #{aggregate_result.strategy}",
      "from: #{aggregate_result.from}"
    )

    %{
      gate: gate,
      chosen: chosen |> Enum.map(fn {n, p, _} -> {n, p} end),
      results: results,
      aggregate: aggregate_result
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
        MoeRising.Logging.log("Router:aggregate", "No results")
        %{strategy: :none, output: ""}

      [_] = [only] ->
        MoeRising.Logging.log("Router:aggregate", "Single result")
        %{strategy: :single, output: only.output, from: only.name}

      _ ->
        MoeRising.Logging.log("Router:aggregate", "Multiple results")
        sys = "You are a helpful judge. Combine the best parts concisely."

        user =
          "Prompt: #{prompt}\n\nCandidates:\n" <>
            Enum.map_join(results, "\n---\n", fn r ->
              "[#{r.name} p=#{Float.round(r.prob, 4)}]\n#{r.output}"
            end)

        # Start async LLM call for aggregation
        task = Task.async(fn -> LLMClient.chat!(sys, user) end)


        # Wait for LLM result with timeout
        result = try do
          case Task.await(task, 60_000) do
            %{content: out, tokens: t} -> %{content: out, tokens: t}
          end
        catch
          :exit, _ ->
            MoeRising.Logging.log("Router:aggregate", "LLM call timed out after 30s")
            raise "LLM call timed out"
        end


        MoeRising.Logging.log(
          "Router:aggregate",
          "LLM completed",
          "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
        )

        MoeRising.Logging.log("Router", "Strategy: judge_llm", "output: #{result.content}")

        %{
          strategy: :judge_llm,
          output: result.content,
          from: Enum.map(results, & &1.name) |> Enum.join(", ")
        }
    end
  end
end
