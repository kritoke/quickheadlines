## ADDED Requirements

### Requirement: Method names under 3 words
All public and private method names in Crystal source files SHALL use at most 3 words (2 underscores). Words are separated by underscores in snake_case naming.

#### Scenario: Getter methods drop get_ prefix
- **WHEN** a method named `get_feed_theme_colors` exists
- **THEN** it SHALL be renamed to `theme_colors`

#### Scenario: Result-returning methods drop _result suffix
- **WHEN** a method named `find_by_url_result` exists
- **THEN** it SHALL be renamed to `find_by_url` with the Result type conveyed by the return signature

#### Scenario: Descriptive methods shortened
- **WHEN** a method named `theme_aware_extract_from_favicon` exists
- **THEN** it SHALL be renamed to `extract_theme_colors`

### Requirement: Files under 400 lines
No single Crystal source file SHALL exceed 400 lines of code after refactoring.

#### Scenario: Large files split
- **WHEN** a file exceeds 400 lines
- **THEN** it SHALL be split into focused modules or extracted helper classes

### Requirement: Idiomatic Crystal patterns
Code SHALL use idiomatic Crystal patterns where applicable:
- `try` blocks instead of `begin/rescue/nil` for simple fallbacks
- `.blank?` or `.presence` instead of `nil? || empty?` checks
- Safe navigation (`&.`) instead of manual nil guards where semantically correct

#### Scenario: Begin/rescue replaced with try
- **WHEN** a method uses `begin; expr; rescue; nil; end` for a simple fallback
- **THEN** it SHALL use `try` or `&.try` instead

#### Scenario: Nil-empty checks simplified
- **WHEN** code checks `value.nil? || value == ""` or `value.nil? || value.empty?`
- **THEN** it SHALL use `value.blank?` or `!value.presence`
