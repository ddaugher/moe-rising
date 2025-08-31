defmodule MoeRising.LLMClient do
  @moduledoc false
  @endpoint "https://api.openai.com/v1/chat/completions"

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
        @endpoint,
        json: body,
        headers: [
          {"authorization", "Bearer #{api_key}"},
          {"content-type", "application/json"}
        ]
      )

    choice = get_in(resp.body, ["choices", Access.at(0), "message", "content"]) || ""
    tokens = get_in(resp.body, ["usage", "total_tokens"]) || 0
    %{content: choice, tokens: tokens}
  end
end
