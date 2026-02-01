# Fix Home Insert Animation

Make Home feed cards apply the timeline-inserted class to newly appended feed items so they animate like the Timeline page.

This change updates Elm function signatures and wiring in `ui/src/Pages/Home_.elm` to pass the `insertedIds` set down to `feedItem` and mark items whose `link` is in the set.
