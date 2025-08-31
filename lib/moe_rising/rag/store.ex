defmodule MoeRising.RAG.Store do
  @moduledoc """
  In-memory ETS store for RAG chunks with simple JSON import/export.

  A chunk is a map:
    %{
      id: "c42",
      title: "Five Years of Building Valuable Things",
      url: "file:///abs/path/priv/a20_docs/2025/08-20-five-years.md",
      text: "chunk text ...",
      embedding: [float(), ...]
    }
  """

  @table :moe_rag_chunks

  # Prefer :code.priv_dir/1 when available (release-friendly); fall back to "priv/" in dev.
  @index_path (try do
                 Path.join([:code.priv_dir(:moe_demo), "a20_index.json"])
               rescue
                 _ -> "priv/a20_index.json"
               end)

  ## ——— Public API ———

  @doc "Create ETS table if missing."
  def ensure_table! do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true, write_concurrency: true])

      _ ->
        :ok
    end

    :ok
  end

  @doc "Remove all rows."
  def clear! do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Insert many chunk maps. Keys are chunk.id."
  def put_many!(chunks) when is_list(chunks) do
    ensure_table!()
    true = :ets.insert(@table, Enum.map(chunks, fn c -> {c.id, c} end))
    :ok
  end

  @doc "Is any index loaded?"
  def loaded? do
    ensure_table!()
    size = :ets.info(@table)[:size]
    is_integer(size) and size > 0
  end

  @doc "Number of rows."
  def count do
    ensure_table!()
    :ets.info(@table)[:size] || 0
  end

  @doc "Load index JSON from disk into ETS."
  def load_from_disk! do
    ensure_table!()

    with {:ok, bin} <- File.read(@index_path),
         {:ok, %{"chunks" => raw}} <- Jason.decode(bin) do
      chunks = Enum.map(raw, &normalize_chunk/1)
      put_many!(chunks)
      {:ok, %{count: length(chunks)}}
    else
      {:error, :enoent} -> {:error, "Index not found at #{@index_path}. Run: mix moe.rag.build"}
      {:error, reason} -> {:error, reason}
      other -> other
    end
  end

  @doc "Save chunks to index JSON file."
  def save_to_disk!(chunks) when is_list(chunks) do
    File.mkdir_p!(Path.dirname(@index_path))
    data = %{chunks: chunks}
    File.write!(@index_path, Jason.encode_to_iodata!(data))
    :ok
  end

  @doc """
  Nearest-neighbor search by cosine similarity.
  Returns a list like: [{score :: float, chunk_map}, ...], sorted desc.
  """
  def search(query_vec, k \\ 6) when is_list(query_vec) and is_integer(k) and k > 0 do
    ensure_table!()

    :ets.tab2list(@table)
    |> Enum.map(fn {_id, c} -> {cos_sim(query_vec, c.embedding), c} end)
    |> Enum.sort_by(fn {s, _} -> -s end)
    |> Enum.take(k)
  end

  ## ——— Helpers ———

  defp normalize_chunk(%{"id" => id, "title" => t, "url" => u, "text" => tx, "embedding" => e}) do
    %{id: id, title: t, url: u, text: tx, embedding: e}
  end

  defp cos_sim(a, b) do
    denom = norm(a) * norm(b)
    if denom <= 0.0, do: 0.0, else: dot(a, b) / denom
  end

  defp dot(a, b), do: Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
  defp norm(v), do: :math.sqrt(Enum.reduce(v, 0.0, fn x, acc -> acc + x * x end))
end
