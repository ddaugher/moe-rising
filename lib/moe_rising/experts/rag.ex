defmodule MoeRising.Experts.RAG do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient
  alias MoeRising.RAG.Store

  @impl true
  def name(), do: "RAG"
  @impl true
  def description(), do: "Answers using augustwenty docs with citations."

  @impl true
  def call(prompt, _opts) do
    MoeRising.Logging.log(
      "RAG",
      "Starting RAG processing",
      "query length: #{String.length(prompt)}"
    )

    ensure_index_loaded()

    MoeRising.Logging.log("RAG", "Index loaded successfully")

    qvec = LLMClient.embed!([prompt]) |> List.first()

    MoeRising.Logging.log("RAG", "Query embedded", "vector length: #{length(qvec)}")

    top = Store.search(qvec, 6)

    MoeRising.Logging.log("RAG", "Search completed", "found #{length(top)} results")

    Enum.with_index(top, 1)
    |> Enum.each(fn {{score, _chunk}, idx} ->
      MoeRising.Logging.log("RAG", "Result #{idx}", "score: #{Float.round(score, 4)}")
    end)

    sources_for_ui =
      top
      |> Enum.with_index(1)
      |> Enum.map(fn {{score, c}, i} ->
        %{
          idx: i,
          title: c.title,
          url: c.url,
          score: Float.round(score, 4),
          preview: String.slice(String.trim(c.text), 0, 300)
        }
      end)

    context =
      top
      |> Enum.with_index(1)
      |> Enum.map(fn {{_score, c}, i} -> "[#{i}] #{c.title} — #{c.url} #{String.trim(c.text)}" end)
      |> Enum.join(" --- ")

    sys =
      "You answer strictly from the provided context. Cite inline like [1], [2], and include a Sources list."

    user = """
    Question: #{prompt}

    Context:
    #{context}
    """

    MoeRising.Logging.log(
      "RAG",
      "Calling LLM",
      "context length: #{String.length(context)}"
    )

    # Start async LLM call
    task = Task.async(fn -> LLMClient.chat!(sys, user) end)

    # Start progress messages concurrently with LLM call
    progress_task = Task.async(fn ->
      workshop_activity = [
        "Setting up the RAG expert workshop...",
        "Gathering #{Enum.random(10..50)} reference documents...",
        "Calibrating knowledge retrieval systems...",
        "Crafting response from retrieved sources...",
        "Polishing each citation and reference...",
        "Quality checking #{Enum.random(3..8)} times...",
        "Packaging final RAG response...",
        "Ready for expert mixture delivery!"
      ]

      Enum.each(workshop_activity, fn msg ->
        MoeRising.Logging.log("RAG", "Status", msg)
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
        MoeRising.Logging.log("RAG", "LLM call timed out after 60s")
        raise "LLM call timed out"
    end

    # Cancel progress task since we got the result
    Task.shutdown(progress_task, :brutal_kill)

    MoeRising.Logging.log(
      "RAG",
      "LLM completed",
      "tokens: #{result.tokens}, output length: #{String.length(result.content)}"
    )

    {:ok, %{output: result.content, tokens: result.tokens, sources: sources_for_ui}}
  rescue
    e ->
      MoeRising.Logging.log("RAG", "Error occurred", e)
      {:error, e}
  end

  defp ensure_index_loaded() do
    if !Store.loaded?() do
      case Store.load_from_disk!() do
        {:error, _} -> raise "No RAG index loaded. Run: mix moe.rag.build"
        _ -> :ok
      end
    end
  end
end
