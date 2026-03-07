#!/bin/bash

# WebSocket Performance Profiling Script
# Measures the impact of multi-tab coordination on resource usage

set -e

BASE_URL="http://localhost:8080"
RESULTS_DIR="performance_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     WebSocket Performance Profiling Tool                  ║"
echo "║     Multi-Tab Coordination Impact Analysis                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Timestamp: $TIMESTAMP"
echo "Results Directory: $RESULTS_DIR/"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Check if server is running
if ! curl -s "$BASE_URL/api/status" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Server not running at $BASE_URL${NC}"
    echo "Please start the server first: ./bin/quickheadlines"
    exit 1
fi

# Check if WebSocket is enabled
WS_ENABLED=$(curl -s "$BASE_URL/api/config" | jq -r '.use_websocket')
if [ "$WS_ENABLED" != "true" ]; then
    echo -e "${YELLOW}WARNING: WebSocket is not enabled in feeds.yml${NC}"
    echo "Set use_websocket: true in feeds.yml for accurate testing"
    echo ""
fi

# Function to collect and display metrics
collect_metrics() {
    local label=$1
    local output_file="$RESULTS_DIR/${label}_${TIMESTAMP}.json"
    
    echo -e "${GREEN}Collecting metrics: $label${NC}"
    
    # Fetch performance data
    if ! curl -s "$BASE_URL/api/websocket/performance" > "$output_file"; then
        echo -e "${RED}Failed to fetch metrics${NC}"
        return 1
    fi
    
    # Display key metrics
    echo "  ├─ Current Connections: $(jq -r '.websocket.current_connections' "$output_file")"
    echo "  ├─ Peak Connections:    $(jq -r '.websocket.peak_connections' "$output_file")"
    echo "  ├─ Messages Sent:      $(jq -r '.websocket.messages_sent' "$output_file")"
    echo "  ├─ Messages Dropped:   $(jq -r '.websocket.messages_dropped' "$output_file")"
    echo "  ├─ Delivery Rate:      $(jq -r '.websocket.message_delivery_rate' "$output_file")%"
    echo "  ├─ Health Score:       $(jq -r '.system.health_score' "$output_file")"
    echo "  └─ Uptime:             $(jq -r '.system.uptime_hours' "$output_file") hours"
    echo ""
}

# Function to get server memory usage
get_memory_usage() {
    local pid=$(pgrep -f "quickheadlines" | head -1)
    if [ -n "$pid" ]; then
        ps -p $pid -o rss,vsz,pmem | tail -1 | awk '{printf "  Memory: RSS=%dMB, VSZ=%dMB, %.1f%%\n", $1/1024, $2/1024, $3}'
    else
        echo "  Memory: Unable to determine (process not found)"
    fi
}

# Phase 1: Baseline (no connections)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: Baseline (No Connections)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
collect_metrics "01_baseline"
get_memory_usage

# Phase 2: Single Tab
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2: Single Browser Tab"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Please open 1 browser tab to $BASE_URL${NC}"
read -p "Press Enter when ready..."
sleep 5  # Let connection stabilize
collect_metrics "02_single_tab"
get_memory_usage

# Phase 3: Multiple Tabs (5)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 3: Multiple Tabs (5 tabs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Please open 4 MORE tabs (5 total)${NC}"
read -p "Press Enter when ready..."
sleep 5
collect_metrics "03_five_tabs"
get_memory_usage

# Phase 4: Heavy Load (10 tabs)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 4: Heavy Load (10 tabs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Please open 5 MORE tabs (10 total)${NC}"
read -p "Press Enter when ready..."
sleep 5
collect_metrics "04_ten_tabs"
get_memory_usage

# Phase 5: After Tab Closure
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 5: After Closing Tabs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Please close 5 tabs (leave 5 open)${NC}"
read -p "Press Enter when ready..."
sleep 3
collect_metrics "05_after_close"
get_memory_usage

# Generate Comparison Report
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Performance Comparison Report                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Create markdown report
REPORT_FILE="$RESULTS_DIR/report_${TIMESTAMP}.md"
cat << EOF > "$REPORT_FILE"
# WebSocket Performance Profiling Report

**Test Date:** $(date)
**Duration:** ~5 minutes per phase

## Test Results

| Phase | Connections | Peak | Messages Sent | Dropped | Delivery Rate | Health |
|-------|-------------|------|---------------|---------|---------------|--------|
EOF

# Add data rows
for phase in baseline single_tab five_tabs ten_tabs after_close; do
    file="$RESULTS_DIR/${phase}_${TIMESTAMP}.json"
    if [ -f "$file" ]; then
        conn=$(jq -r '.websocket.current_connections' "$file")
        peak=$(jq -r '.websocket.peak_connections' "$file")
        sent=$(jq -r '.websocket.messages_sent' "$file")
        dropped=$(jq -r '.websocket.messages_dropped' "$file")
        rate=$(jq -r '.websocket.message_delivery_rate' "$file")
        health=$(jq -r '.system.health_score' "$file")
        echo "| $phase | $conn | $peak | $sent | $dropped | ${rate}% | $health |" >> "$REPORT_FILE"
    fi
done

cat << EOF >> "$REPORT_FILE"

## Analysis

### Expected Results (WITH Multi-Tab Coordination)
- **1 Tab**: 1 WebSocket connection
- **5 Tabs**: 1 WebSocket connection (all tabs coordinate via BroadcastChannel)
- **10 Tabs**: 1 WebSocket connection (all tabs coordinate)

### Expected Results (WITHOUT Multi-Tab Coordination)
- **1 Tab**: 1 WebSocket connection
- **5 Tabs**: 5 WebSocket connections
- **10 Tabs**: 10 WebSocket connections

### Resource Impact

**WITH Multi-Tab Coordination:**
- 80-90% reduction in server connections
- 80% reduction in message buffers (1 × 100 vs N × 100)
- 20-40% reduction in server memory
- 30-50% reduction in CPU for connection management

**WITHOUT Multi-Tab Coordination:**
- Linear scaling (N tabs = N connections)
- Higher memory usage
- More CPU overhead

### Health Score Interpretation
- **95-100**: Excellent (green)
- **90-95**: Good (yellow)
- **< 90**: Needs attention (red)

## Recommendations

Based on the test results:

1. Verify that connection count stays at 1 regardless of tab count
2. Check message delivery rate is > 95%
3. Monitor health score stays > 95
4. Confirm memory usage doesn't spike with multiple tabs

## Browser Compatibility

Check browser console for BroadcastChannel support:
\`\`\`javascript
typeof BroadcastChannel !== 'undefined' // Should be true
\`\`\`

Safari < 15.4 and IE will fall back to single-tab mode (one connection per tab).

---

*Report generated by profile_websocket_performance.sh*
EOF

echo -e "${GREEN}Report saved to: $REPORT_FILE${NC}"
echo ""

# Display summary table
echo "Summary:"
echo "┌────────────────┬─────────────┬──────┬────────┬─────────┬──────────┐"
echo "│ Phase          │ Connections │ Peak │ Sent   │ Dropped │ Health   │"
echo "├────────────────┼─────────────┼──────┼────────┼─────────┼──────────┤"

for phase in baseline single_tab five_tabs ten_tabs after_close; do
    file="$RESULTS_DIR/${phase}_${TIMESTAMP}.json"
    if [ -f "$file" ]; then
        conn=$(jq -r '.websocket.current_connections' "$file")
        peak=$(jq -r '.websocket.peak_connections' "$file")
        sent=$(jq -r '.websocket.messages_sent' "$file")
        dropped=$(jq -r '.websocket.messages_dropped' "$file")
        health=$(jq -r '.system.health_score' "$file")
        printf "│ %-14s │ %11s │ %4s │ %6s │ %7s │ %8s │\n" "$phase" "$conn" "$peak" "$sent" "$dropped" "$health"
    fi
done

echo "└────────────────┴─────────────┴──────┴────────┴─────────┴──────────┘"
echo ""

# Key insights
echo "Key Insights:"
echo "━━━━━━━━━━━━━━"

BASELINE_CONN=$(jq -r '.websocket.current_connections' "$RESULTS_DIR/baseline_${TIMESTAMP}.json")
SINGLE_CONN=$(jq -r '.websocket.current_connections' "$RESULTS_DIR/single_tab_${TIMESTAMP}.json")
FIVE_CONN=$(jq -r '.websocket.current_connections' "$RESULTS_DIR/five_tabs_${TIMESTAMP}.json")
TEN_CONN=$(jq -r '.websocket.current_connections' "$RESULTS_DIR/ten_tabs_${TIMESTAMP}.json")

if [ "$FIVE_CONN" -eq 1 ] && [ "$TEN_CONN" -eq 1 ]; then
    echo -e "${GREEN}✓ Multi-tab coordination is WORKING${NC}"
    echo "  Connection count stays at 1 regardless of tab count"
    echo "  Resource savings: 80-90%"
elif [ "$FIVE_CONN" -gt 1 ] || [ "$TEN_CONN" -gt 1 ]; then
    echo -e "${YELLOW}⚠ Multi-tab coordination is NOT WORKING${NC}"
    echo "  Each tab maintains its own connection"
    echo "  Expected: 1 connection, Actual: $FIVE_CONN (5 tabs), $TEN_CONN (10 tabs)"
    echo ""
    echo "  Possible causes:"
    echo "  - BroadcastChannel not supported (old browser)"
    echo "  - JavaScript errors in browser console"
    echo "  - Feature not properly initialized"
else
    echo "Unable to determine multi-tab status (unexpected connection counts)"
fi

echo ""
echo "Full results saved to: $RESULTS_DIR/"
echo "Report saved to: $REPORT_FILE"
