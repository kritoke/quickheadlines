---
description: "WP03: Stable Integration (The Clustered List)"
lane: "planned"
---

# WP03: Stable Integration (The Clustered List)

## Constitutional Requirements
> **Reference:** QuickHeadlines Constitution v1.1.0
> - **Styling:** ALL Elm Land UI MUST use `elm-ui` (`mdgriffith/elm-ui`). **Strictly Forbidden:** `Html`, `Html.Attributes`, `class` tags, and Tailwind/CSS frameworks.

## Goal
Wire the existing SQLite data into the new Elm frontend and display clusters in a list.

## Actions

### 1. API Module
Create `ui/src/Api/News.elm`. Write a decoder that matches the `NewsClusterDTO` from WP01.

### 2. Fetching
In `ui/src/Pages/Home_.elm`, fetch clusters from the new Athena endpoint.

### 3. The List View
Use `Element.column` to render a vertical list of headlines.
- Display the source count and "Time Ago" using the `Theme.metadataStyle`.

## Definition of Done
The homepage displays your actual SQLite clusters in a stable Elm-ui list.

## Implementation Steps

### Step 1: Create Api/News.elm
- Create `ui/src/Api/News.elm`
- Import `Json.Decode`
- Create decoder matching NewsClusterDTO structure:
  - id: Int
  - title: String
  - timestamp: String (ISO 8601 format)
  - source_count: Int
- Create fetchClusters function using `Http.get`

### Step 2: Update Home_ page
- Modify `ui/src/Pages/Home_.elm`
- Import `Api.News`
- Add clusters to the Page.Model
- Add fetchClusters Msg variant
- Call `Api.News.fetchClusters` in update

### Step 3: Render cluster list
- **Use `Element.column`** to render vertical list - NO `Html.div`, NO `Html.li`
- For each cluster, display title using `Element.text`
- Use `Theme.metadataStyle` for:
  - Source count (e.g., "3 sources")
  - Time ago (e.g., "2 hours ago")
- Handle loading and error states using `Element` primitives

### Step 4: Connect to Shared model
- Update Shared.Model to include clusters
- Pass clusters to Home_ page
- Ensure proper initialization
