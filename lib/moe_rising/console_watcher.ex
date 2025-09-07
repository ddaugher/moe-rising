defmodule MoeRising.ConsoleWatcher do
  @moduledoc """
  Watches a console output file and sends updates to LiveView processes.
  Uses a simple polling approach to check for file changes.
  Only sends activity log entries (prefixed with [ACTIVITY]) to LiveView.
  """

  use GenServer

  @console_file "console_output.log"
  # Check every 100ms for more responsive updates
  @poll_interval 100
  # Prefix to identify activity log entries
  @activity_log_prefix "[ACTIVITY]"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_liveview_pid(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:add_liveview, pid})
  end

  def remove_liveview_pid(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:remove_liveview, pid})
  end

  def init(_opts) do
    # Create the console output file if it doesn't exist
    File.touch(@console_file)

    # Start polling for changes
    Process.send_after(self(), :poll_file, @poll_interval)

    {:ok,
     %{
       liveview_pids: MapSet.new(),
       last_position: 0
     }}
  end

  def handle_call({:add_liveview, pid}, _from, state) do
    new_pids = MapSet.put(state.liveview_pids, pid)
    {:reply, :ok, %{state | liveview_pids: new_pids}}
  end

  def handle_call({:remove_liveview, pid}, _from, state) do
    new_pids = MapSet.delete(state.liveview_pids, pid)
    {:reply, :ok, %{state | liveview_pids: new_pids}}
  end

  def handle_info(:poll_file, state) do
    # Schedule next poll
    Process.send_after(self(), :poll_file, @poll_interval)

    # Check for new content
    new_state = read_new_content(state)
    {:noreply, new_state}
  end

  defp read_new_content(state) do
    case File.read(@console_file) do
      {:ok, content} ->
        content_length = String.length(content)

        # Handle case where file was truncated or reset
        {new_content, new_position} =
          cond do
            state.last_position > content_length ->
              # File was reset/cleared, don't send anything, just reset position
              {"", content_length}

            state.last_position == content_length ->
              # No new content
              {"", content_length}

            state.last_position < content_length ->
              # Only send new content since last position
              {String.slice(content, state.last_position, content_length - state.last_position),
               content_length}

            true ->
              # Fallback
              {"", content_length}
          end

        if String.length(new_content) > 0 and String.valid?(new_content) do
          # Filter for activity log entries only
          activity_log_content = filter_activity_log_entries(new_content)

          if String.length(activity_log_content) > 0 do
            # Send filtered content to all LiveView processes
            Enum.each(state.liveview_pids, fn pid ->
              if Process.alive?(pid) do
                send(pid, {:console_output, activity_log_content})
              end
            end)
          end
        end

        %{state | last_position: new_position}

      {:error, _reason} ->
        state
    end
  end

  defp filter_activity_log_entries(content) do
    content
    |> String.split("\n")
    |> Enum.filter(fn line ->
      String.starts_with?(line, @activity_log_prefix)
    end)
    |> Enum.join("\n")
  end

end
