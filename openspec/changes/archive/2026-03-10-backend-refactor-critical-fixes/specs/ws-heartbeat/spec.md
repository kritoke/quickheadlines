# WebSocket Heartbeat

## Overview

This spec covers the WebSocket connection health monitoring through ping/pong heartbeat mechanism.

## ADDED Requirements

### Requirement: Server sends periodic pings

The WebSocket server SHALL send ping frames to connected clients at regular intervals.

#### Scenario: Ping sent at interval
- **WHEN** client is connected via WebSocket
- **THEN** server sends a PING frame every 30 seconds
- **AND** does not wait for client to respond before continuing normal operation

### Requirement: Client must respond to pings

Connected clients SHALL respond to server pings with pong frames.

#### Scenario: Client responds to ping
- **WHEN** server sends PING to client
- **AND** client responds with PONG within 10 seconds
- **THEN** connection remains active
- **AND** last_pong_time is updated

### Requirement: Stale connections cleaned up

Connections that miss pings SHALL be cleaned up by the janitor.

#### Scenario: Client misses ping
- **GIVEN** client connected with last_pong_time = T
- **WHEN** 60 seconds pass without receiving PONG (2 missed pings)
- **AND** janitor runs cleanup
- **THEN** connection is closed and removed
- **AND** cleanup is logged

### Requirement: Heartbeat stats exposed

WebSocket statistics SHALL include heartbeat health information.

#### Scenario: Stats show heartbeat status
- **WHEN** `SocketManager#get_stats` is called
- **THEN** returned statistics include connection_count
- **AND** entries track last_pong_time for each connection
