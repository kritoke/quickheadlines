## ADDED Requirements

### Requirement: SQL LIKE Pattern Escaping

All user-controlled strings used in SQL LIKE patterns SHALL be escaped to prevent SQL injection. The escaping function MUST escape the following characters: `\`, `%`, `_`, `[`, `]`, `^`, `-`.

#### Scenario: Keywords from feed titles are escaped
- **WHEN** `find_by_keywords` is called with keywords derived from a feed title
- **THEN** each keyword is escaped before being inserted into the LIKE pattern
- **AND** SQL LIKE wildcards in the original title are treated as literal characters

#### Scenario: Malicious title with LIKE wildcards
- **WHEN** a feed title contains `%` or `_` characters
- **THEN** those characters are escaped to `\%` and `\_`
- **AND** the resulting query matches only literal occurrences

### Requirement: Keyword Extraction Validation

Keywords extracted from external content SHALL be validated before use in database queries.

#### Scenario: Empty keyword list
- **WHEN** `find_by_keywords` is called with an empty keyword array
- **THEN** an empty result is returned immediately
- **AND** no database query is executed

#### Scenario: Nil or blank keywords
- **WHEN** keywords contain nil or blank strings
- **THEN** those are filtered out before query construction
- **AND** only non-empty keywords are used in the LIKE clause
