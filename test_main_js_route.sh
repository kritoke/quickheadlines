#!/bin/bash

echo "Checking if server is running..."
if ! curl -s http://localhost:8080 > /dev/null; then
    echo "Server is not running. Starting server in background..."
    nix develop . --command ./quickheadlines config=feeds.yml > server.log 2>&1 &
    PID=$!
    echo "Server started with PID: $PID"
    # Wait for server to start
    sleep 2
fi

echo "Checking /__mint__/main.js route..."
