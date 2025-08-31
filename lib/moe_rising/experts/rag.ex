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
    IO.inspect({:rag_start, prompt}, label: "RAG")

    ensure_index_loaded()
    IO.inspect({:rag_index_loaded}, label: "RAG")

    qvec = LLMClient.embed!([prompt]) |> List.first()
    IO.inspect({:rag_embedded, length(qvec)}, label: "RAG")

    top = Store.search(qvec, 6)
    IO.inspect({:rag_searched, length(top)}, label: "RAG")

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
      |> Enum.map(fn {{_score, c}, i} -> "[#{i}] #{c.title} — #{c.url}


  #{String.trim(c.text)}" end)
      |> Enum.join("


  ---


  ")

    sys =
      "You answer strictly from the provided context. Cite inline like [1], [2], and include a Sources list."

    user = "Question: #{prompt}


  Context:
  #{context}"

    IO.inspect({:rag_calling_llm}, label: "RAG")
    %{content: out, tokens: t} = LLMClient.chat!(sys, user)
    IO.inspect({:rag_llm_done, t}, label: "RAG")

    {:ok, %{output: out, tokens: t, sources: sources_for_ui}}
  rescue
    e ->
      IO.inspect({:rag_error, e}, label: "RAG")
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
