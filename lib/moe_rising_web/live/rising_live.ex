defmodule MoeRisingWeb.MoeLive do
  use MoeRisingWeb, :live_view
  alias MoeRising.Router

  def mount(_params, _session, socket) do
    {:ok, assign(socket, q: "", res: nil, loading: false, log_messages: [])}
  end

  defp source_bg_color(score, scores) when is_number(score) and is_list(scores) do
    sorted_scores = Enum.sort(scores, :desc)
    rank = Enum.find_index(sorted_scores, fn s -> s == score end)
    total = length(scores)

    if rank == 0 do
      "bg-green-50 border-green-200"
    else
      percentile = rank / total
      cond do
        percentile <= 0.2 -> "bg-green-50 border-green-200"
        percentile <= 0.4 -> "bg-yellow-50 border-yellow-200"
        percentile <= 0.6 -> "bg-orange-50 border-orange-200"
        percentile <= 0.8 -> "bg-red-50 border-red-200"
        true -> "bg-gray-50 border-gray-200"
      end
    end
  end

  defp source_bg_color(_, _), do: "bg-gray-50 border-gray-200"

  def handle_event("route", %{"q" => q}, socket) do
    # Capture the LiveView process ID
    liveview_pid = self()

    # Add a log message for the new query
    MoeRising.Logging.log(liveview_pid, "System", "Starting new query: #{String.slice(q, 0, 50)}#{if String.length(q) > 50, do: "...", else: ""}")

    # Start async task to avoid blocking the LiveView
    task = Task.async(fn -> Router.route(q, log_pid: liveview_pid) end)

    # Debug: print current state
    IO.puts("LIVEVIEW: Route event triggered, current log_messages: #{length(socket.assigns.log_messages)}")
    IO.puts("LIVEVIEW: Process ID: #{inspect(liveview_pid)}")

    {:noreply,
     socket
     |> assign(q: q, loading: true, res: nil)
     |> assign(:task, task)}
  end

  def handle_info({ref, result}, %{assigns: %{task: %Task{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(res: result, loading: false)
     |> assign(:task, nil)}
  end

  def handle_info({:log_message, message}, socket) do
    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()
    log_entry = "#{timestamp} - #{message}"

    # Debug: print to console to verify messages are being received
    IO.puts("LIVEVIEW: Received log message: #{log_entry}")
    IO.puts("LIVEVIEW: Current log_messages count: #{length(socket.assigns.log_messages)}")
    IO.puts("LIVEVIEW: Process ID: #{inspect(self())}")

    {:noreply,
     socket
     |> update(:log_messages, fn messages -> [log_entry | messages] end)
     |> push_event("scroll-log", %{})}
  end

  def handle_info({:console_message, message}, socket) do
    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()
    log_entry = "#{timestamp} - [CONSOLE] #{message}"

    {:noreply,
     socket
     |> update(:log_messages, fn messages -> [log_entry | messages] end)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{assigns: %{task: %Task{ref: ref}}} = socket) do
    {:noreply,
     socket
     |> assign(loading: false, res: %{error: "Task failed: #{inspect(reason)}"})
     |> assign(:task, nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="w-full p-6 space-y-6">
        <div class="text-center">
          <h1 class="text-3xl font-bold">Mixture of Experts Demo</h1>
          <p class="text-gray-600">
            Type a prompt; the gate will score experts and route to the topK.
          </p>
        </div>

        <.form for={%{}} phx-submit="route" class="space-y-3">
          <div>
            <textarea
              name="q"
              rows="4"
              class="w-full border rounded-lg p-3 focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
              placeholder="e.g., What is augustwenty's stance on professional standards?"
            ><%= @q %></textarea>
          </div>
          <button
            type="submit"
            class="btn btn-primary"
            disabled={@loading}
          >
            <%= if @loading do %>
              <div class="flex items-center space-x-2">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                <span>Processing...</span>
              </div>
            <% else %>
              Run
            <% end %>
          </button>
        </.form>

        <%= if @loading do %>
          <div class="text-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-600 mx-auto mb-4"></div>
            <p class="text-gray-600">Processing your query...</p>
            <p class="text-sm text-gray-500 mt-2">This may take a few moments</p>
          </div>
        <% end %>

        <div class="border rounded-lg p-4 bg-black">
          <h3 class="text-sm font-semibold mb-2 text-green-400">Activity Log (<%= length(@log_messages) %> messages)</h3>
          <div id="activity-log" class="max-h-60 overflow-y-auto space-y-0 bg-black text-green-400 font-mono text-xs p-2" phx-hook="AutoScroll">
            <%= if length(@log_messages) > 0 do %>
              <%= for message <- Enum.reverse(@log_messages) do %>
                <div class="text-green-400">
                  <%= message %>
                </div>
              <% end %>
            <% else %>
              <div class="text-gray-500">
                No activity yet...
              </div>
            <% end %>
          </div>
        </div>

        <%= if @res do %>
          <div class="space-y-6">
            <div>
              <h2 class="text-xl font-semibold mb-3">Gate Probabilities</h2>
              <div class="space-y-2">
                <%= for {name, prob} <- @res.gate.ranked do %>
                  <div>
                    <div class="flex justify-between text-sm">
                      <span class="font-medium"><%= name %></span>
                      <span><%= :io_lib.format("~.2f", [prob]) %></span>
                    </div>
                    <div class="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
                      <div
                        class="h-2 bg-orange-500 rounded-full transition-all duration-300"
                        style={"width: #{Float.round(prob*100, 1)}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <div>
              <h2 class="text-xl font-semibold mb-3">Expert Outputs Top-2</h2>
              <div class="grid md:grid-cols-2 gap-4">
                <%= for r <- @res.results do %>
                  <div class="border rounded-lg p-4 shadow-sm bg-white">
                    <div class="text-sm text-gray-500 mb-2">
                      Expert: <span class="font-medium"><%= r.name %></span> ·
                      p≈<%= :io_lib.format("~.2f", [r.prob]) %> ·
                      tokens: <%= r.tokens %>
                    </div>
                    <pre class="whitespace-pre-wrap text-sm bg-gray-50 p-3 rounded border"><%= r.output %></pre>

                    <%= if Map.has_key?(r, :sources) and is_list(r.sources) do %>
                      <div class="mt-3 space-y-2">
                        <div class="text-sm font-medium">Retrieved Sources</div>
                        <div class="grid gap-2">
                          <%= for s <- r.sources do %>
                            <div class={"rounded border p-2 #{source_bg_color(s.score, Enum.map(r.sources, & &1.score))}"}>
                              <div class="flex items-center justify-between text-xs text-gray-600">
                                <span>[<%= s.idx %>] score ≈ <%= :io_lib.format("~.3f", [s.score]) %></span>
                                <a
                                  href={s.url}
                                  class="underline hover:text-orange-600"
                                  target="_blank"
                                >
                                  open
                                </a>
                              </div>
                              <div class="text-sm font-semibold mt-1"><%= s.title %></div>
                              <div class="text-xs text-gray-700 mt-1"><%= s.preview %>…</div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <div>
              <h2 class="text-xl font-semibold mb-3">Final Answer</h2>
              <div class="border rounded-lg p-4 bg-white">
                <div class="text-sm text-gray-500 mb-2">
                  strategy: <%= @res.aggregate.strategy %> (from: <%= @res.aggregate.from %>)
                </div>
                <pre class="whitespace-pre-wrap text-sm bg-gray-50 p-3 rounded border"><%= @res.aggregate.output %></pre>
              </div>
            </div>

            <%= if rag = Enum.find(@res.results, fn rr -> rr.name == "RAG" and Map.has_key?(rr, :sources) end) do %>
              <div class="space-y-2">
                <h2 class="text-xl font-semibold mb-3">RAG Retrieved Sources</h2>
                <div class="grid md:grid-cols-3 lg:grid-cols-4 gap-3">
                  <%= for s <- rag.sources do %>
                    <div class={"rounded-lg border p-3 shadow-sm #{source_bg_color(s.score, Enum.map(rag.sources, & &1.score))}"}>
                      <div class="flex items-center justify-between text-xs text-gray-600">
                        <span>[<%= s.idx %>] score ≈ <%= :io_lib.format("~.3f", [s.score]) %></span>
                        <a href={s.url} class="underline hover:text-orange-600" target="_blank">
                          open
                        </a>
                      </div>
                      <div class="text-sm font-semibold mt-1"><%= s.title %></div>
                      <div class="text-xs text-gray-700 mt-1"><%= s.preview %>…</div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
