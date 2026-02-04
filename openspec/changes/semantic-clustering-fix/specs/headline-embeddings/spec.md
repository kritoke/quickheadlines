# headline-embeddings Specification

## Purpose
Generate and manage sentence embeddings for headlines using external embedding API. Provides a service layer for embedding generation, caching, and storage.

## Requirements
### Requirement: Embedding API Client
The system SHALL provide an HTTP client for generating embeddings via an external API (OpenAI text-embedding-3-small or equivalent).

#### Scenario: API Integration
- **WHEN** a headline is passed to the embedding service
- **THEN** the service SHALL call the embedding API and return a 384-dimensional vector

### Requirement: Batch Embedding Support
The embedding service SHALL support batching multiple headlines into a single API request.

#### Scenario: Batch Request
- **WHEN** a batch of headlines is provided
- **THEN** the service SHALL call the API once with all headlines and return corresponding embeddings

### Requirement: Error Handling
The embedding service SHALL gracefully handle API errors by logging and raising a descriptive exception.

#### Scenario: API Failure
- **WHEN** the embedding API returns an error
- **THEN** the service SHALL log the error and raise a ClusteringError with details

### Requirement: Caching
The embedding service SHALL cache embeddings by headline text to avoid regenerating embeddings for identical headlines.

#### Scenario: Duplicate Headline
- **WHEN** the same headline is embedded twice
- **THEN** the second request SHALL return the cached embedding without an API call

### Requirement: Configuration
The embedding service SHALL read API configuration from environment variables or configuration file.

#### Scenario: Configuration Loading
- **WHEN** the service initializes
- **THEN** it SHALL load API key and endpoint from EMBEDDING_API_KEY and EMBEDDING_API_URL environment variables
