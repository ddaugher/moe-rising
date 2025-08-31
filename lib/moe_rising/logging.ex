defmodule MoeRising.Logging do
  @moduledoc """
  Logging system that can capture messages and send them to LiveView processes.
  """

  def log(process_pid, message) when is_pid(process_pid) do
    if Process.alive?(process_pid) do
      IO.puts("LOGGING: Sending message to #{inspect(process_pid)}: #{message}")
      send(process_pid, {:log_message, message})
    else
      IO.puts("LOGGING: Process #{inspect(process_pid)} is not alive")
    end
  end

  def log(process_pid, label, data) when is_pid(process_pid) do
    message = "#{label}: #{inspect(data)}"
    log(process_pid, message)
  end

  def log(process_pid, label, data, metadata) when is_pid(process_pid) do
    message = "#{label}: #{inspect(data)} - #{inspect(metadata)}"
    log(process_pid, message)
  end

  def console_log(process_pid, message) when is_pid(process_pid) do
    if Process.alive?(process_pid) do
      send(process_pid, {:console_message, message})
    end
  end
end
