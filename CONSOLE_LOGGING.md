# Console Output Logging

This application now captures all console output and displays it in the activity log in real-time.

## How It Works

1. **Activity Log Prefix**: All `MoeRising.Logging.log` calls write to `console_output.log` with a `[ACTIVITY]` prefix
2. **File Watching**: The `MoeRising.ConsoleWatcher` process monitors the console output file for changes
3. **Smart Filtering**: Only lines with the `[ACTIVITY]` prefix are sent to the LiveView activity log
4. **Clean Display**: The `[ACTIVITY]` prefix is removed before displaying in the UI
5. **Manual Clearing**: Users can clear the activity log on demand using the "Clear Log" button

## For Live Demos

When you run the application, you'll see:

### Console Output File:
```
[debug] Live reload: lib/moe_rising_web/live/rising_live.ex
[ACTIVITY] [21:35:00.422212] System: "Starting new query"
[info] GET /moe
[ACTIVITY] [21:35:00.423119] RAG: "Processing RAG search"
[debug] Processing with MoeRisingWeb.MoeLive
[ACTIVITY] [21:35:00.423288] Writing: "Generating content"
```

### Activity Log (Filtered):
Only the `[ACTIVITY]` prefixed messages appear in the activity log textarea:
```
[21:35:00.422212] System: "Starting new query"
[21:35:00.423119] RAG: "Processing RAG search"
[21:35:00.423288] Writing: "Generating content"
```

## Starting the Application

### Option 1: Normal Start
```bash
mix phx.server
```

### Option 2: With Console Logging (Recommended for Demos)
```bash
./start_with_console_log.sh
```

This will redirect all console output to `console_output.log` and the activity log will show it in real-time.

## Clearing the Activity Log

You can clear the activity log at any time using the "Clear Log" button located next to the "Activity Log" heading. This will:

- Clear the console output file (`console_output.log`)
- Clear the activity log display in the UI
- Give you a fresh start for monitoring new queries

This is particularly useful for:
- Starting a new demo with a clean log
- Focusing on a specific query's output
- Managing log size during long sessions

## Benefits for Conference Demos

- **Proves it's real**: Console output shows the system is actually running
- **No boredom**: Constant activity keeps attendees engaged
- **Visual appeal**: Emojis make it easy to follow what's happening
- **Dual visibility**: Both console and UI show the same information
- **Simple setup**: Just run the application normally
- **User control**: Clear the activity log whenever you want with the "Clear Log" button
- **Clean separation**: Only activity log entries appear in the UI, not general console chatter

## Technical Details

- Activity log entries are written to `console_output.log` with `[ACTIVITY]` prefix
- `MoeRising.ConsoleWatcher` polls the file every 100ms
- Only lines starting with `[ACTIVITY]` are filtered and sent to LiveView processes
- The `[ACTIVITY]` prefix is removed before displaying in the UI
- The activity log textarea auto-expands to show all content
- General console output (Phoenix debug messages, etc.) is ignored by the activity log
