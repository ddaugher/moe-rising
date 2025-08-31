defmodule MoeRising.ProgressTicker do
  @moduledoc """
  Progress ticker that streams progress messages to give users a sense of activity.
  """

  @progress_steps [
    "Scanning prompt for keywords",
    "Gate model rolling dice",
    "Top-K experts selected",
    "Routing prompt down expert highway",
    "Writing Expert warming up its tone analyzer",
    "Code Expert opening iex",
    "Math Expert sharpening pencil",
    "RAG Expert rummaging through dusty augustwenty docs",
    "Experts drafting first thoughts",
    "Waiting for network latency",
    "Parallel threads spun up",
    "Token counter humming",
    "Code Expert spotting bugs you didn’t know existed",
    "Writing Expert rephrasing things thrice",
    "Math Expert checking work twice",
    "RAG Expert whispering from your docs",
    "Experts pushing results onto message bus",
    "Gate double-checking confidence scores",
    "Aggregator judging submissions",
    "LLM Judge hallucinating slightly",
    "Softmax knobs tuned",
    "Final answer chosen",
    "Sources glued on",
    "Packaging response",
    "Shipping to browser",
    "Loading embeddings from cache",
    "Splitting documents into chunks",
    "Normalizing vectors for comparison",
    "Calculating cosine similarities",
    "Ranking candidate chunks",
    "Pruning low-probability experts",
    "Dispatching tasks to async workers",
    "Waiting on external API response",
    "Checking rate limits",
    "Retrying failed requests",
    "Collecting expert outputs",
    "Measuring token usage",
    "Logging intermediate results",
    "Checking aggregator strategy",
    "Resolving ties between experts",
    "Truncating overly long outputs",
    "Stripping unsafe content",
    "Formatting answer for UI",
    "Escaping markdown characters",
    "Appending citations",
    "Building final JSON payload",
    "Sending response over socket",
    "Flushing telemetry events",
    "Cleaning up temporary processes",
    "Returning control to LiveView"
  ]

  def start_ticker(liveview_pid, _delay_ms \\ 350) do
    spawn(fn -> stream_progress(liveview_pid) end)
  end

  def check_if_should_stop(liveview_pid) do
    try do
      # Send a message to check if LiveView is still loading
      send(liveview_pid, {:check_loading, self()})
      # Wait a short time for response
      receive do
        {:loading_status, false} -> true
        {:loading_status, true} -> false
      after
        50 -> false  # Assume still loading if no response
      end
    rescue
      _ -> true  # Stop if we can't communicate with LiveView
    end
  end

  def stop_ticker(ticker_pid) when is_pid(ticker_pid) do
    Process.exit(ticker_pid, :normal)
  end

  def stop_ticker(_), do: :ok

  defp stream_progress(liveview_pid) do
    Enum.each(@progress_steps, fn step ->
      if Process.alive?(liveview_pid) do
        # Check if we should stop before sending the message
        if check_if_should_stop(liveview_pid) do
          exit(:normal)
        end

        MoeRising.Logging.log(liveview_pid, "Progress", step)
        # Random delay between 5-10 seconds (5000-10000ms)
        random_delay = :rand.uniform(2001) + 4999
        Process.sleep(random_delay)
      else
        # Stop if the LiveView process is no longer alive
        exit(:normal)
      end
    end)
  end
end
