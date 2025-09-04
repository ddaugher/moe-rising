defmodule MoeRisingWeb.MoeLive do
  use MoeRisingWeb, :live_view
  alias MoeRising.Router
  alias MoeRising.Gate

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, q: "", res: nil, loading: false, log_messages: [], attention_analysis: nil,
            processing_phase: :idle)}
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

  defp highlight_keywords(text, keywords) do
    keywords
    |> Enum.reduce(text, fn keyword, acc ->
      # Use case-insensitive replacement with word boundaries to match whole words only
      String.replace(
        acc,
        ~r/\b#{Regex.escape(keyword)}\b/i,
        "<span class=\"bg-yellow-200 px-1 py-0.5 rounded font-mono text-sm\">#{keyword}</span>"
      )
    end)
  end

  defp get_expert_keywords do
    Gate.__experts__()
  end

  defp get_ordered_expert_analysis(attention_analysis) do
    ["RAG", "Writing", "Code", "Math", "DataViz"]
    |> Enum.map(fn expert_name ->
      {expert_name, Map.get(attention_analysis.analysis, expert_name)}
    end)
    |> Enum.filter(fn {_name, analysis} -> analysis != nil end)
  end

  defp contains_whole_word(text, keyword) do
    # Use regex with word boundaries to match whole words only
    String.match?(text, ~r/\b#{Regex.escape(keyword)}\b/i)
  end


  defp phase_comes_before?(phase, current_phase) do
    phase_order = [:input_analysis, :gate_analysis_complete, :routing_experts, :expert_processing, :aggregating_results, :complete]
    phase_index = Enum.find_index(phase_order, &(&1 == phase))
    current_index = Enum.find_index(phase_order, &(&1 == current_phase))

    if phase_index && current_index do
      phase_index < current_index
    else
      false
    end
  end

  defp analyze_attention(prompt) do
    gate_result = Gate.score(prompt)
    experts = get_expert_keywords()

    analysis =
      for {name, keywords} <- experts, into: %{} do
        hits = Enum.count(keywords, &contains_whole_word(String.downcase(prompt), &1))
        score = Map.fetch!(gate_result.scores, name)
        prob = Map.fetch!(gate_result.probs, name)

        {name,
         %{
           keywords: keywords,
           hits: hits,
           raw_score: score,
           probability: prob,
           matched_keywords: Enum.filter(keywords, &contains_whole_word(String.downcase(prompt), &1))
         }}
      end

    %{
      prompt: prompt,
      analysis: analysis,
      gate_result: gate_result
    }
  end

  def handle_event("route", %{"q" => q}, socket) do
    # Capture the LiveView process ID
    liveview_pid = self()

    # Add a log message for the new query
    MoeRising.Logging.log(
      liveview_pid,
      "System",
      "Starting new query: #{String.slice(q, 0, 50)}#{if String.length(q) > 50, do: "...", else: ""}"
    )

    # Analyze attention before routing
    attention_analysis = analyze_attention(q)

    # Start async task to avoid blocking the LiveView
    task = Task.async(fn -> Router.route(q, log_pid: liveview_pid) end)

    # Start a timer to simulate phase progression (slower, more realistic)
    Process.send_after(self(), :update_processing_phase, 4000)

    {:noreply,
     socket
     |> assign(q: q, loading: true, res: nil, attention_analysis: attention_analysis,
                processing_phase: :input_analysis)
     |> assign(:task, task)}
  end

  def handle_info({ref, result}, %{assigns: %{task: %Task{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])

    # Add completion message
    MoeRising.Logging.log(self(), "System", "Query completed successfully")

    {:noreply,
     socket
     |> assign(res: result, loading: false, processing_phase: :complete)
     |> assign(:task, nil)}
  end

  def handle_info({:log_message, message}, socket) do
    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()
    log_entry = "#{timestamp} - #{message}"

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

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{assigns: %{task: %Task{ref: ref}}} = socket
      ) do
    # Add error message
    MoeRising.Logging.log(self(), "System", "Query failed: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(loading: false, res: %{error: "Task failed: #{inspect(reason)}"})
     |> assign(:task, nil)}
  end

  def handle_info(:update_processing_phase, %{assigns: %{processing_phase: current_phase, loading: true}} = socket) do
    next_phase = get_next_phase(current_phase)

    # Only advance if we're not in the final phase
    if next_phase != :complete do
      # More conservative timing - wait longer between phases
      # This better reflects actual processing time
      delay = case current_phase do
        :input_analysis -> 3000          # 3 seconds for input analysis
        :gate_analysis_complete -> 6000  # 6 seconds for routing
        :routing_experts -> 8000         # 8 seconds for expert processing
        :expert_processing -> 5000       # 5 seconds for aggregation
        _ -> 3000
      end

      Process.send_after(self(), :update_processing_phase, delay)
    end

    {:noreply, assign(socket, processing_phase: next_phase)}
  end

  def handle_info(:update_processing_phase, socket), do: {:noreply, socket}

  defp get_next_phase(current_phase) do
    case current_phase do
      :input_analysis -> :gate_analysis_complete
      :gate_analysis_complete -> :routing_experts
      :routing_experts -> :expert_processing
      :expert_processing -> :aggregating_results
      :aggregating_results -> :complete
      _ -> :complete
    end
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
          <!-- Processing Section - Show at top when loading -->
          <div class="text-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-600 mx-auto mb-4">
            </div>
            <p class="text-gray-600">Processing your query...</p>
            <p class="text-sm text-gray-500 mt-2">This may take a few moments</p>

          </div>

          <!-- Activity Log - Show at top when loading -->
          <div class="border border-gray-300 p-2 bg-white">
            <h3 class="text-sm font-semibold mb-2 text-black">
              Activity Log ({length(@log_messages)} messages)
            </h3>
            <div
              id="activity-log"
              class="max-h-60 overflow-y-auto space-y-0 bg-white text-black font-mono text-xs p-2 border border-gray-200"
              phx-hook="AutoScroll"
            >
              <%= if length(@log_messages) > 0 do %>
                <%= for message <- Enum.reverse(@log_messages) do %>
                  <div class="text-black">
                    {message}
                  </div>
                <% end %>
              <% else %>
                <div class="text-gray-600">
                  No activity yet...
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @attention_analysis != nil do %>
          <div class="space-y-6">
            <!-- 1. Attention Phase Analysis -->
            <%= if phase_comes_before?(:input_analysis, @processing_phase) do %>
            <div>
                <h2 class="text-xl font-semibold mb-4 text-center">🧠 Attention Phase Analysis</h2>
                <p class="text-gray-600 text-center mb-6">
                  See how the gate analyzes your prompt and calculates attention scores for each expert
                </p>
              </div>
            <% end %>

            <!-- 1. Attention Process Flow -->
            <%= if phase_comes_before?(:input_analysis, @processing_phase) do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
                <h3 class="text-lg font-medium text-green-900 mb-4">🔄 Attention Process Flow</h3>
                <div class="flex items-center justify-center space-x-4 mb-4">
                  <div class="text-center">
                    <div class="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-sm mb-2">
                      1
                    </div>
                    <div class="text-xs text-gray-600">Input Prompt</div>
                  </div>
                  <div class="text-blue-400 text-2xl">→</div>
                  <div class="text-center">
                    <div class="w-12 h-12 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-sm mb-2">
                      2
                    </div>
                    <div class="text-xs text-gray-600">Keyword<br />Matching</div>
                  </div>
                  <div class="text-green-400 text-2xl">→</div>
                  <div class="text-center">
                    <div class="w-12 h-12 bg-purple-500 rounded-full flex items-center justify-center text-white font-bold text-sm mb-2">
                      3
                    </div>
                    <div class="text-xs text-gray-600">Score<br />Calculation</div>
                  </div>
                  <div class="text-purple-400 text-2xl">→</div>
                  <div class="text-center">
                    <div class="w-12 h-12 bg-orange-500 rounded-full flex items-center justify-center text-white font-bold text-sm mb-2">
                      4
                    </div>
                    <div class="text-xs text-gray-600">Softmax<br />Normalization</div>
                  </div>
                  <div class="text-orange-400 text-2xl">→</div>
                  <div class="text-center">
                    <div class="w-12 h-12 bg-red-500 rounded-full flex items-center justify-center text-white font-bold text-sm mb-2">
                      5
                    </div>
                    <div class="text-xs text-gray-600">Expert<br />Selection</div>
                  </div>
                </div>
                <div class="text-center text-sm text-gray-600">
                  <p class="mb-2">The attention mechanism follows this 5-step process:</p>
                  <ol class="list-decimal list-inside space-y-1 text-center max-w-2xl mx-auto">
                    <li><strong>Input Analysis:</strong> Parse and tokenize the user's prompt</li>
                    <li>
                      <strong>Keyword Matching:</strong>
                      Count how many expert-specific keywords appear in the prompt
                    </li>
                    <li>
                      <strong>Score Calculation:</strong>
                      Apply formula: base_weight × (1 + keyword_matches)
                    </li>
                    <li>
                      <strong>Softmax Normalization:</strong>
                      Convert raw scores to probabilities that sum to 1.0
                    </li>
                    <li>
                      <strong>Expert Selection:</strong>
                      Route to top-k experts based on attention probabilities
                    </li>
                  </ol>
                </div>
              </div>
            <% end %>

            <!-- 2. Input Prompt Analysis -->
            <%= if phase_comes_before?(:gate_analysis_complete, @processing_phase) do %>
              <div class="bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-lg p-4 mb-6">
                <h3 class="text-lg font-medium text-blue-900 mb-3">📝 Input Prompt Analysis</h3>
                <div class="bg-white border rounded p-3">
                  <div class="text-sm text-gray-600 mb-2">Keywords detected and highlighted:</div>
                  <div class="text-gray-800 leading-relaxed">
                    <%= if @attention_analysis do %>
                      <%= Phoenix.HTML.raw(
                        highlight_keywords(
                          @attention_analysis.prompt,
                          @attention_analysis.analysis
                          |> Map.values()
                          |> Enum.flat_map(& &1.matched_keywords)
                          |> Enum.uniq()
                          |> Enum.sort_by(&String.length/1, :desc)
                        )
                      ) %>
                    <% else %>
                      <span class="text-gray-400 italic">Submit a prompt to see keyword analysis...</span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- 3. Score Calculation -->
            <%= if phase_comes_before?(:routing_experts, @processing_phase) do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
                <h3 class="text-lg font-medium text-orange-900 mb-4">🧮 Score Calculation</h3>
                <p class="text-sm text-orange-700 mb-4">
                  Each expert's attention score is calculated using the formula: <strong>base_weight × (1 + keyword_matches)</strong>
                </p>

                <!-- Expert Attention Visualization -->
                <div class="grid gap-6">
                <%= for {expert_name, analysis} <- get_ordered_expert_analysis(@attention_analysis) do %>
                  <div class="border rounded-lg p-4 bg-white shadow-sm attention-expert-card">
                    <div class="flex items-center justify-between mb-3">
                      <h4 class="text-lg font-semibold text-gray-800">{expert_name}</h4>
                      <div class="text-right attention-probability">
                        <div class="text-2xl font-bold text-blue-600">
                          {Float.round(analysis.probability * 100, 1) |> Float.to_string()}%
                        </div>
                        <div class="text-sm text-gray-500">probability</div>
                      </div>
                    </div>

    <!-- Attention Flow Diagram -->
                    <div class="space-y-3">
                      <!-- Keywords Row -->
                      <div class="flex items-center space-x-2">
                        <span class="text-sm font-medium text-gray-600 w-20">Keywords:</span>
                        <div class="flex flex-wrap gap-1">
                          <%= for keyword <- analysis.keywords do %>
                            <span class={[
                              "px-2 py-1 rounded-full text-xs font-mono",
                              if(keyword in analysis.matched_keywords,
                                do:
                                  "bg-green-100 text-green-800 border border-green-200 attention-keyword-match",
                                else: "bg-gray-100 text-gray-600 border border-gray-200"
                              )
                            ]}>
                              {keyword}
                            </span>
                          <% end %>
                        </div>
                      </div>

    <!-- Matches Row -->
                      <div class="flex items-center space-x-2">
                        <span class="text-sm font-medium text-gray-600 w-20">Matches:</span>
                        <div class="flex items-center space-x-2">
                          <span class="text-lg font-bold text-green-600">{analysis.hits}</span>
                          <span class="text-sm text-gray-500">keywords found</span>
                        </div>
                      </div>

    <!-- Score Calculation -->
                      <div class="flex items-center space-x-2">
                        <span class="text-sm font-medium text-gray-600 w-20">Score:</span>
                        <div class="flex items-center space-x-2">
                          <span class="text-sm text-gray-500">base weight × (1 + matches)</span>
                          <span class="text-gray-400">→</span>
                          <span class="font-mono text-sm bg-gray-100 px-2 py-1 rounded">
                            {Map.fetch!(MoeRising.Gate.__weights__(), expert_name)} × (1 + {analysis.hits}) = {Float.round(analysis.raw_score, 2) |> Float.to_string()}
                          </span>
                        </div>
                      </div>

    <!-- Probability Bar -->
                      <div class="space-y-1">
                        <div class="flex justify-between text-sm text-gray-600">
                                                  <span>Attention Score</span>
                        <span>{Float.round(analysis.probability, 3) |> Float.to_string()}</span>
                        </div>
                        <div class="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
                          <div
                            class="h-3 bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all duration-1000 ease-out attention-bar"
                            style={"width: #{Float.round(analysis.probability * 100, 1)}%"}
                          >
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
                </div>
              </div>
            <% end %>

            <!-- 4. Gate Probabilities -->
            <%= if phase_comes_before?(:expert_processing, @processing_phase) do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
                <h3 class="text-lg font-medium text-emerald-900 mb-3">🎯 Gate Probabilities</h3>
                <p class="text-sm text-emerald-700 mb-4">
                  Final attention probabilities after softmax normalization. The top 2 experts will be selected for processing.
                </p>

              <div class="space-y-2">
                  <%= for {{name, prob}, index} <- Enum.with_index(@attention_analysis.gate_result.ranked) do %>
                    <div class="rounded border p-3 bg-white">
                    <div class="flex justify-between text-sm">
                      <span class="font-medium">{name}</span>
                        <span>{Float.round(prob, 2) |> Float.to_string()}</span>
                    </div>
                    <div class="w-full h-2 bg-gray-200 rounded-full overflow-hidden mt-2">
                      <div
                        class={"h-2 #{if index < 2, do: if(index == 0, do: "bg-green-500", else: "bg-yellow-500"), else: "bg-gray-500"} rounded-full transition-all duration-300"}
                        style={"width: #{Float.round(prob*100, 1)}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
            <% end %>

            <!-- 5. Attention Flow Summary -->
            <%= if phase_comes_before?(:expert_processing, @processing_phase) do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 attention-flow-summary">
                <h3 class="text-lg font-medium text-purple-900 mb-3">🎯 Attention Flow Summary</h3>
                <div class="space-y-4">
                  <!-- Top Experts with Details -->
                  <div>
                    <div class="text-sm font-medium text-purple-700 mb-3">Top Experts Selected (Whole Word Matching):</div>
                    <div class="space-y-3">
                      <%= for {{name, prob}, index} <- Enum.take(@attention_analysis.gate_result.ranked, 2) do %>
                        <div class="bg-white rounded-lg p-3 border border-purple-200">
                          <div class="flex items-center justify-between mb-2">
                            <div class="flex items-center space-x-2">
                              <div class={[
                                "w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold text-white",
                                if(index == 0, do: "bg-green-500", else: "bg-yellow-500")
                              ]}>
                                {index + 1}
                              </div>
                              <span class="font-medium text-purple-900">{name}</span>
                            </div>
                            <div class="text-right">
                              <div class="text-lg font-bold text-purple-600">
                                {Float.round(prob * 100, 1) |> Float.to_string()}%
                              </div>
                              <div class="text-xs text-purple-500">probability</div>
                            </div>
                          </div>

                          <%= if Map.get(@attention_analysis.analysis, name) do %>
                            <% expert_analysis = Map.get(@attention_analysis.analysis, name) %>
                            <div class="text-sm text-gray-600">
                              <span class="font-medium">Keywords matched:</span> {expert_analysis.hits}
                              <%= if expert_analysis.hits > 0 do %>
                                <span class="text-purple-600">({expert_analysis.matched_keywords |> Enum.join(", ")})</span>
                              <% else %>
                                <span class="text-gray-400">(no whole word matches)</span>
                              <% end %>
                            </div>
                            <div class="text-sm text-gray-600">
                              <span class="font-medium">Raw score:</span> {Float.round(expert_analysis.raw_score, 2) |> Float.to_string()}
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <!-- Routing Decision -->
                  <div class="bg-white rounded-lg p-3 border border-purple-200">
                    <div class="text-sm font-medium text-purple-700 mb-2">🚀 Routing Decision:</div>
                    <div class="text-sm text-gray-700 space-y-2">
                      <p>
                        The gate uses <strong>whole word matching</strong> to analyze your prompt against expert-specific keywords.
                        Experts are scored based on how many of their keywords appear as complete words in your query.
                      </p>
                      <p>
                        Your query will be routed to the top 2 experts with the highest attention scores.
                        Higher attention means the expert is more likely to have relevant knowledge for your specific query.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

          </div>
        <% end %>







        <%= if @res do %>
          <div class="space-y-6">

            <!-- 5. Expert Outputs Top-2 -->
            <%= if @res && @processing_phase == :complete do %>
            <div>
              <h2 class="text-xl font-semibold mb-3">Expert Outputs Top-2</h2>
              <div class="grid md:grid-cols-2 gap-4">
                <%= for r <- @res.results do %>
                  <div class="border rounded-lg p-4 shadow-sm bg-white">
                    <div class="text-sm text-gray-500 mb-2">
                      Expert: <span class="font-medium">{r.name}</span> ·
                      p≈{Float.round(r.prob, 2) |> Float.to_string()} ·
                      tokens: {r.tokens}
                    </div>
                    <pre class="whitespace-pre-wrap text-sm bg-gray-50 p-3 rounded border"><%= r.output %></pre>

                    <%= if Map.has_key?(r, :sources) and is_list(r.sources) do %>
                      <div class="mt-3 space-y-2">
                        <div class="text-sm font-medium">Retrieved Sources</div>
                        <div class="grid gap-2">
                          <%= for s <- r.sources do %>
                            <div class={"rounded border p-2 #{source_bg_color(s.score, Enum.map(r.sources, & &1.score))}"}>
                              <div class="flex items-center justify-between text-xs text-gray-600">
                                <span>[{s.idx}] score ≈ {Float.round(s.score, 3) |> Float.to_string()}</span>
                                <a
                                  href={s.url}
                                  class="underline hover:text-orange-600"
                                  target="_blank"
                                >
                                  open
                                </a>
                              </div>
                              <div class="text-sm font-semibold mt-1">{s.title}</div>
                              <div class="text-xs text-gray-700 mt-1">{s.preview}…</div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
            <% end %>

            <!-- 6. Final Answer -->
            <%= if @res && @processing_phase == :complete do %>
            <div>
              <h2 class="text-xl font-semibold mb-3">Final Answer</h2>
              <div class="border rounded-lg p-4 bg-white">
                <div class="text-sm text-gray-500 mb-2">
                  strategy: {@res.aggregate.strategy} (from: {@res.aggregate.from})
                </div>
                <pre class="whitespace-pre-wrap text-sm bg-gray-50 p-3 rounded border"><%= @res.aggregate.output %></pre>
              </div>
            </div>
            <% end %>
          </div>
        <% end %>

        <!-- 7. Processing Complete -->
        <%= if @processing_phase == :complete and @res != nil do %>
          <div class="text-center py-6 bg-gray-50 border rounded-lg">
            <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-sm mx-auto mb-3">
              ✓
                </div>
            <p class="text-gray-700 font-medium">Processing Complete!</p>
            <p class="text-sm text-gray-500 mt-1">Your query has been processed successfully</p>
          </div>
        <% end %>


      </div>
    </Layouts.app>
    """
  end
end
