defmodule MoeRising.Gate do
  @moduledoc """
  Lightweight gate that produces a probability for each expert.
  Replace this with Nx/EXLA later without changing the map shape.
  """

  @experts [
    # {"RAG", ~w(augustwenty a20 journal policy splashlight dmx nimblepublisher docs business)},
    {"Writing", ~w(explain summary outline write tone prose paragraph blog doc clarify)},
    {"Code", ~w(elixir phoenix liveview mix ecto code bug compile error module function)},
    {"Math", ~w(sum add subtract multiply divide integral derivative probability matrix)},
    {"DataViz", ~w(chart plot graph visualization data visual encoding)}
  ]

  # @weights %{"Writing" => 1.0, "Code" => 1.0, "Math" => 1.0, "DataViz" => 1.0, "RAG" => 1.0}
  @weights %{"Writing" => 1.0, "Code" => 1.0, "Math" => 1.0, "DataViz" => 1.0}

  def score(prompt) do
    p = String.downcase(prompt)

    raw =
      for {name, keywords} <- @experts, into: %{} do
        hits = Enum.count(keywords, &contains_whole_word(p, &1))
        w = Map.fetch!(@weights, name)
        {name, w * (1.0 + hits)}
      end

    probs = softmax(raw)

    %{
      scores: raw,
      probs: probs,
      ranked:
        @experts
        |> Enum.map(fn {name, _keywords} -> {name, Map.fetch!(probs, name)} end)
        |> Enum.sort_by(fn {_name, prob} -> -prob end)
    }
  end

  def __experts__, do: @experts

  def __weights__, do: @weights

  defp contains_whole_word(text, keyword) do
    # Use regex with word boundaries to match whole words only
    String.match?(text, ~r/\b#{Regex.escape(keyword)}\b/i)
  end

  defp softmax(map) do
    vals = Map.values(map)
    maxv = Enum.max(vals)
    exps = for v <- vals, do: :math.exp(v - maxv)
    z = Enum.sum(exps)

    map
    |> Map.keys()
    |> Enum.zip(exps)
    |> Enum.into(%{}, fn {k, e} -> {k, e / z} end)
  end
end
