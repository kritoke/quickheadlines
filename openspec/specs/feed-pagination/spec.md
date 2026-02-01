# feed-pagination Specification

## Purpose
TBD

## Requirements

### Requirement: Consistent "Load More" Visibility
The system SHALL only display the "Load More" button for a feed if there are more items available to fetch from the backend.

#### Scenario: Feed has more items
- **WHEN** the number of displayed items is less than the `total_item_count` for that feed
- **THEN** the "Load More" button MUST be visible

#### Scenario: Feed is exhausted
- **WHEN** the number of displayed items is equal to or greater than the `total_item_count`
- **THEN** the "Load More" button SHALL NOT be visible

### Requirement: Standardized "Load More" Styling
The "Load More" button SHALL use consistent styling across all views (Home and Timeline).

#### Scenario: Button styling on Home page
- **WHEN** viewing a feed card on the Home page
- **THEN** the "Load More" button SHALL have 12px font size, 4px 12px padding, and a background color of `#f1f5f9`

#### Scenario: Button styling on Timeline page
- **WHEN** viewing the Timeline page
- **THEN** the "Load More" button SHALL have 12px font size, 4px 12px padding, and a background color of `#f1f5f9`

### Requirement: Case-Insensitive Tab API
The backend API SHALL handle tab parameters case-insensitively, specifically ensuring the "all" tab works regardless of casing.

#### Scenario: Fetching feeds with "All" tab
- **WHEN** a request is made to `/api/feeds?tab=All`
- **THEN** the system SHALL return the same result as `/api/feeds?tab=all`
