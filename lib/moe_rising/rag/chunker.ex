defmodule MoeRising.RAG.Chunker do
  @moduledoc """
  Simple overlapping character-window chunker.

  Example:
    iex> MoeRising.RAG.Chunker.chunk("abcdef", 4, 2)
    [%{idx: 0, text: "abcd"}, %{idx: 1, text: "cdef"}]
  """

  @default_size 1200
  @default_overlap 200

  @spec chunk(String.t(), pos_integer(), non_neg_integer()) :: [
          %{idx: non_neg_integer(), text: String.t()}
        ]
  def chunk(text, size \\ @default_size, overlap \\ @default_overlap) do
    text = String.trim(to_string(text))
    do_chunk(text, size, overlap, 0, [])
  end

  defp do_chunk("", _size, _ovl, _i, acc), do: Enum.reverse(acc)

  defp do_chunk(text, size, ovl, i, acc) when size > 0 do
    len = String.length(text)
    take = String.slice(text, 0, min(size, len))
    acc = [%{idx: i, text: take} | acc]

    if len <= size do
      Enum.reverse(acc)
    else
      # step forward with overlap
      start = max(0, size - ovl)
      next = String.slice(text, start, len - start)
      do_chunk(next, size, ovl, i + 1, acc)
    end
  end
end
