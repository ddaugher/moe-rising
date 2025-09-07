defmodule MoeRising.Logging do
  @moduledoc """
  Logging system that writes messages to console_output.log for the activity log.
  """

  # Prefix to identify activity log entries
  @activity_log_prefix "[ACTIVITY]"

  def log(message) do
    # Write to console output file for activity log
    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()
    formatted_message = "#{@activity_log_prefix} [#{timestamp}] #{message}"
    File.write!("console_output.log", formatted_message <> "\n", [:append])

    # Small delay to ensure file write is complete before ConsoleWatcher reads it
    Process.sleep(10)
  end

  def log(label, data) do
    message = "#{label}: #{inspect(data)}"
    log(message)
  end

  def log(label, data, metadata) do
    message = "#{label}: #{inspect(data)} - #{inspect(metadata)}"
    log(message)
  end
end
