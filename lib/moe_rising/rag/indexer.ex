defmodule MoeRising.RAG.Indexer do
  alias MoeRising.RAG.{Chunker, Store}
  alias MoeRising.LLMClient

  @src_glob "priv/a20_docs/**/*.{md,mdx,markdown,txt}"

  def build_index!() do
    files = Path.wildcard(@src_glob)
    if files == [], do: raise("No docs found. Put your a20 markdowns under priv/a20_docs/.")

    chunks =
      files
      |> Enum.flat_map(&file_to_chunks/1)

    embeddings =
      chunks
      |> Enum.map(& &1.text)
      # batch embeddings
      |> Enum.chunk_every(64)
      |> Enum.flat_map(&LLMClient.embed!/1)

    enriched =
      Enum.zip(chunks, embeddings)
      |> Enum.with_index()
      |> Enum.map(fn {{c, emb}, i} -> Map.merge(c, %{id: "c#{i}", embedding: emb}) end)

    Store.save_to_disk!(enriched)
    Store.clear!()
    Store.put_many!(enriched)

    %{count: length(enriched)}
  end

  defp file_to_chunks(path) do
    base = Path.basename(path)

    title =
      case File.read!(path) |> String.split("\n") do
        ["# " <> t | _] -> String.trim(t)
        _ -> Path.rootname(base)
      end

    text = File.read!(path)
    url = "file://" <> Path.expand(path)

    Chunker.chunk(text)
    |> Enum.map(fn %{idx: idx, text: t} ->
      %{title: title, url: url, text: t, source: base, part: idx}
    end)
  end
end
