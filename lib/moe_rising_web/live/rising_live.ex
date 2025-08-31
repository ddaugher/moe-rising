defmodule MoeRisingWeb.MoeLive do
  use MoeRisingWeb, :live_view
  alias MoeRising.Router

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, q: "", res: nil)}
  end

  @impl true
  def handle_event("route", %{"q" => q}, socket) do
    res = Router.route(q, top_k: 2)
    {:noreply, assign(socket, q: q, res: res)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6 space-y-6">
      <h1 class="text-3xl font-bold">Mixture‑of‑Experts Demo</h1>
      <p class="text-gray-600">Type a prompt; the gate will score experts and route to the top‑K.</p>

      <form phx-submit="route" class="space-y-3">
        <textarea
          name="q"
          rows="4"
          class="w-full border rounded p-3"
          placeholder="e.g., Write a Phoenix LiveView that shows a counter with buttons..."
        ><%= @q %></textarea>
        <button class="px-4 py-2 rounded bg-indigo-600 text-white">Run</button>
      </form>

      <%= if @res do %>
        <div class="space-y-4">
          <h2 class="text-xl font-semibold">Gate Probabilities</h2>
          <div class="space-y-2">
            <%= for {name, prob} <- @res.gate.ranked do %>
              <div>
                <div class="flex justify-between text-sm">
                  <span class="font-medium">{name}</span>
                  <span>{:io_lib.format("~.2f", [prob])}</span>
                </div>
                <div class="w-full h-2 bg-gray-200 rounded">
                  <div class="h-2 bg-indigo-500 rounded" style={"width: #{Float.round(prob*100, 1)}%"}>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <h2 class="text-xl font-semibold">Expert Outputs (Top‑2)</h2>
          <div class="grid md:grid-cols-2 gap-4">
            <%= for r <- @res.results do %>
              <div class="border rounded p-3 shadow-sm">
                <div class="text-sm text-gray-500">
                  Expert: <span class="font-medium">{r.name}</span>
                  · p≈{:io_lib.format("~.2f", [r.prob])} · tokens: {r.tokens}
                </div>
                <pre class="whitespace-pre-wrap text-sm mt-2"> <%= r.output %> </pre>
              </div>
            <% end %>
          </div>

          <h2 class="text-xl font-semibold">Final Answer</h2>
          <div class="border rounded p-3">
            <div class="text-sm text-gray-500">
              strategy: {@res.aggregate.strategy} (from: {@res.aggregate.from})
            </div>
            <pre class="whitespace-pre-wrap text-sm mt-2"> <%= @res.aggregate.output %> </pre>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
