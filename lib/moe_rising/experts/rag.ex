defmodule MoeRising.Experts.RAG do
  @behaviour MoeRising.Expert
  alias MoeRising.LLMClient
  alias MoeRising.RAG.Store

  @impl true
  def name(), do: "RAG"
  @impl true
  def description(), do: "Answers using augustwenty docs with citations."

  @impl true
  def call(prompt, opts) do
    log_pid = Keyword.get(opts, :log_pid)

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "RAG",
        "Starting RAG processing",
        "query length: #{String.length(prompt)}"
      )
    end

    ensure_index_loaded()

    if log_pid do
      MoeRising.Logging.log(log_pid, "RAG", "Index loaded successfully")
    end

    qvec = LLMClient.embed!([prompt]) |> List.first()

    if log_pid do
      MoeRising.Logging.log(log_pid, "RAG", "Query embedded", "vector length: #{length(qvec)}")
    end

    top = Store.search(qvec, 6)

    if log_pid do
      MoeRising.Logging.log(log_pid, "RAG", "Search completed", "found #{length(top)} results")

      Enum.with_index(top, 1)
      |> Enum.each(fn {{score, _chunk}, idx} ->
        MoeRising.Logging.log(log_pid, "RAG", "Result #{idx}", "score: #{Float.round(score, 4)}")
      end)
    end

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

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "RAG",
        "Calling LLM",
        "context length: #{String.length(context)}"
      )

    end

    %{content: out, tokens: t} = LLMClient.chat!(sys, user)

    if log_pid do
      MoeRising.Logging.log(
        log_pid,
        "RAG",
        "LLM completed",
        "tokens: #{t}, output length: #{String.length(out)}"
      )
    end

    {:ok, %{output: out, tokens: t, sources: sources_for_ui}}
  rescue
    e ->
      log_pid = Keyword.get(opts, :log_pid)

      if log_pid do
        MoeRising.Logging.log(log_pid, "RAG", "Error occurred", e)
      end

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
