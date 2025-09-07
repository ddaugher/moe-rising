#!/bin/bash

# Start the Phoenix server with console output redirected to console_output.log
# This allows the activity log to show all console output in real-time

echo "Starting MoeRising with console output logging..."
echo "Console output will be saved to console_output.log"
echo "The activity log will show this output in real-time"
echo ""

# Start the server and redirect all output to the console log file
mix phx.server 2>&1 | tee console_output.log
