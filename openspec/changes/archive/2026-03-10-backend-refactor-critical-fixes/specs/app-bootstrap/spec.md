# App Bootstrap

## Overview

This spec covers the structured application initialization that separates service setup from background task management.

## ADDED Requirements

### Requirement: AppBootstrap class exists

The application SHALL have a dedicated `AppBootstrap` class for initialization.

#### Scenario: AppBootstrap class created
- **WHEN** application starts
- **THEN** `src/services/app_bootstrap.cr` exists with `AppBootstrap` class
- **AND** class takes `Config` as constructor dependency

### Requirement: Services initialization separated

The initialization process SHALL separate service creation from background task startup.

#### Scenario: Initialize services without spawning fibers
- **WHEN** `AppBootstrap#initialize_services` is called
- **THEN** database service is created
- **AND** feed cache is loaded
- **AND** favicon storage is initialized
- **AND** no background fibers are spawned

### Requirement: Background tasks configurable

Background task intervals SHALL be configurable through the Config object, not hardcoded.

#### Scenario: Feed refresh interval from config
- **GIVEN** config has `refresh_minutes: 30`
- **WHEN** background feed refresh starts
- **THEN** refresh loop runs every 30 minutes

#### Scenario: Clustering interval from config
- **GIVEN** config has clustering settings
- **WHEN** clustering scheduler starts
- **THEN** runs at configured interval (default 60 minutes)

### Requirement: Multiple background tasks managed

The bootstrap SHALL manage multiple background tasks with proper lifecycle.

#### Scenario: Background tasks spawn correctly
- **WHEN** `AppBootstrap#start_background_tasks` is called
- **THEN** spawns: WebSocket janitor (5 min), feed refresh loop, clustering scheduler (60 min), old article cleanup (6 hours)
- **AND** all tasks run concurrently

### Requirement: Error handling in background tasks

Background tasks SHALL have proper error handling to prevent one failure from crashing others.

#### Scenario: Background task error doesn't crash app
- **GIVEN** one background task throws an exception
- **WHEN** that task's loop catches the exception
- **THEN** task logs error and continues to next iteration
- **AND** other background tasks continue running
