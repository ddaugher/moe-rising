defmodule MoeRising.LLMClient do
  @moduledoc false

  @chat_endpoint "https://api.openai.com/v1/chat/completions"
  @embed_endpoint "https://api.openai.com/v1/embeddings"

  # --- Chat completions ---
  def chat!(system, user, _opts \\ []) do
    model = System.get_env("MOE_LLM_MODEL", "gpt-4o-mini")
    api_key = System.fetch_env!("OPENAI_API_KEY")

    body = %{
      model: model,
      messages: [
        %{role: "system", content: system},
        %{role: "user", content: user}
      ]
    }

    resp =
      Req.post!(
        @chat_endpoint,
        json: body,
        headers: [
          {"authorization", "Bearer #{api_key}"},
          {"content-type", "application/json"}
        ],
        receive_timeout: 60_000
      )

    content = get_in(resp.body, ["choices", Access.at(0), "message", "content"]) || ""
    tokens = get_in(resp.body, ["usage", "total_tokens"]) || 0
    %{content: content, tokens: tokens}
  end

  # --- Embeddings ---
  @doc """
  Embed a list of texts; returns a list of vectors (list of floats).
  """
  def embed!(texts, opts \\ []) when is_list(texts) do
    model = Keyword.get(opts, :model, System.get_env("MOE_EMBED_MODEL", "text-embedding-3-small"))
    api_key = System.fetch_env!("OPENAI_API_KEY")

    resp =
      Req.post!(
        @embed_endpoint,
        json: %{model: model, input: texts},
        headers: [
          {"authorization", "Bearer #{api_key}"},
          {"content-type", "application/json"}
        ],
        receive_timeout: 30_000
      )

    for item <- get_in(resp.body, ["data"]) do
      get_in(item, ["embedding"]) || []
    end
  end
end
