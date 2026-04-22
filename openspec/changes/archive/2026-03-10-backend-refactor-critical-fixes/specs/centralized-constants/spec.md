# Centralized Constants

## Overview

This spec covers the centralization of all magic numbers and configuration constants into a single source of truth.

## ADDED Requirements

### Requirement: Single constants module

The codebase SHALL have a single `Constants` module that defines all magic numbers used across the application.

#### Scenario: Constants module exists
- **WHEN** application starts
- **THEN** `src/constants.cr` exists and defines `Constants` module
- **AND** module contains all application-wide numeric constants

### Requirement: Concurrency constant defined

The `CONCURRENCY` constant SHALL be defined in the constants module.

#### Scenario: Concurrency constant accessible
- **WHEN** code references `Constants::CONCURRENCY`
- **THEN** value equals 8 (number of concurrent feed fetches)

### Requirement: Cache retention constants defined

Cache retention constants SHALL be defined in the constants module.

#### Scenario: Cache retention hours constant
- **WHEN** code references `Constants::CACHE_RETENTION_HOURS`
- **THEN** value equals 168 (7 days * 24 hours)

#### Scenario: Cache retention days constant
- **WHEN** code references `Constants::CACHE_RETENTION_DAYS`
- **THEN** value equals 7 (article retention in days)

### Requirement: Constants used throughout codebase

All code that previously defined magic numbers inline SHALL reference the constants module instead.

#### Scenario: No duplicate constant definitions
- **GIVEN** the constants module defines `CONCURRENCY = 8`
- **WHEN** code is searched for `CONCURRENCY = ` (assignment)
- **THEN** only the definition in `constants.cr` matches
- **AND** all other files import from constants module
