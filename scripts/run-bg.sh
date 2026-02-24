#!/bin/bash
# Start QuickHeadlines server in background with proper detachment

LOG_FILE="/tmp/quickheadlines.log"
PID_FILE="/tmp/quickheadlines.pid"

# Stop existing server
pkill -f quickheadlines 2>/dev/null || true
sleep 1

# Start server with nohup and redirect output
cd /workspaces/quickheadlines
nohup ./bin/quickheadlines > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Save PID
echo $SERVER_PID > "$PID_FILE"

# Disown the process to detach from shell
disown $SERVER_PID

# Wait for server to start
echo "Starting server (PID: $SERVER_PID)..."
sleep 3

# Check if server is responding
if curl -s http://0.0.0.0:8080/ > /dev/null 2>&1; then
    echo "✓ Server running on http://0.0.0.0:8080"
    echo "  PID: $SERVER_PID"
    echo "  Logs: $LOG_FILE"
else
    echo "❌ Server failed to start. Check logs:"
    echo "  tail -50 $LOG_FILE"
    exit 1
fi
