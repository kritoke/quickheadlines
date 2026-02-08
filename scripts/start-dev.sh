#!/usr/bin/env bash
# Start the development server in background and write logs/pid
set -euo pipefail
mkdir -p /tmp
nohup make run > /tmp/qh-server.log 2>&1 &
echo $! > /tmp/qh-server.pid
echo "server-started pid=$(cat /tmp/qh-server.pid) log=/tmp/qh-server.log"
