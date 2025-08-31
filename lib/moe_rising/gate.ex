defmodule MoeRising.Gate do
  @moduledoc """
  Lightweight gate that produces a probability for each expert.
  Replace this with Nx/EXLA later without changing the map shape.
  """

  @experts [
    {"Writing", ~w(explain summary outline write tone prose paragraph blog doc clarify)},
    {"Code", ~w(elixir phoenix liveview mix ecto code bug compile error module function)},
    {"Math", ~w(sum add subtract multiply divide integral derivative probability matrix)},
    {"DataViz", ~w(chart plot graph visualization data visual encoding)},
    {"RAG", ~w(augustwenty a20 journal policy splashlight dmx nimblepublisher docs business)}
  ]

  @weights %{"Writing" => 1.0, "Code" => 1.0, "Math" => 1.0, "DataViz" => 1.0, "RAG" => 1.0}

  def score(prompt) do
    p = String.downcase(prompt)

    raw =
      for {name, keywords} <- @experts, into: %{} do
        hits = Enum.count(keywords, &String.contains?(p, &1))
        w = Map.fetch!(@weights, name)
        {name, w * (1.0 + hits)}
      end

    probs = softmax(raw)

    %{
      scores: raw,
      probs: probs,
          ranked:
      @experts
      |> Enum.with_index()
      |> Enum.map(fn {{name, _keywords}, index} -> {name, Map.fetch!(probs, name), index} end)
      |> Enum.sort_by(fn {_name, prob, index} -> {-prob, index} end)
      |> Enum.map(fn {name, prob, _index} -> {name, prob} end)
    }
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
