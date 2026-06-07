# JSON Search — Design

**Date:** 2026-06-07
**Status:** Approved (design)
**Tool:** JSON Formatter (`JsonTool`)

## Goal

Add a search function to the JSON Formatter. The user searches across the
formatted JSON output and can either **highlight & jump** between matches or
**filter** the view to only matching paths. Search applies to both output
views, each doing what it does best.

## Requirements (from brainstorming)

- **Both behaviors:** highlight-and-jump *and* filter-to-matches.
- **Match scope:** object **keys and** scalar **values** (string, number, bool, null).
- **Matching:** case-insensitive substring by default, with an opt-in **regex** toggle.
- **Per-view fit:**
  - **Text view** → highlight all matches + step through them (next/prev).
  - **Tree view** → highlight matches + a "filter to matches" toggle that
    collapses non-matching paths (ancestors of matches stay open).
- **Placement:** a search field in the result pane header, beside the
  Text/Tree segmented control; visible when there is valid JSON.

## Non-goals (YAGNI)

- Filtering the **text** view (hiding lines). Text view highlights everything
  and jumps; only the tree filters. (Per the per-view-fit decision.)
- Search/replace. Read-only output search only.
- Searching the raw **input** editor. Output only.
- Persisting search state across app launches.

## Architecture

Approach A: one pure, testable matcher shared by both views; each view renders
matches in its own way. The matcher stays free of SwiftUI so it can be unit
tested like the rest of the JSON engine.

### Core matcher — new file `JSONSearch.swift`

```swift
struct JSONSearch {
    let query: String
    let isRegex: Bool
    private let regex: NSRegularExpression?   // nil when query empty OR invalid regex

    /// Usable matcher: non-empty query that compiled.
    var isActive: Bool      { !query.isEmpty && regex != nil }
    /// Regex mode with a non-empty but uncompilable pattern.
    var hasRegexError: Bool { isRegex && !query.isEmpty && regex == nil }

    init(query: String, isRegex: Bool)

    func matches(_ s: String) -> Bool
    func ranges(in s: String) -> [NSRange]
}
```

Both modes compile to a single `NSRegularExpression` with `.caseInsensitive`:

- **Substring mode:** escape the query with `NSRegularExpression.escapedPattern(for:)`.
- **Regex mode:** use the query as the raw pattern.

This unifies `matches`/`ranges` and gives invalid-regex handling for free
(`regex == nil`). Empty query and invalid regex both yield `isActive == false`,
so callers treat "no usable search" uniformly.

Pure tree helpers (also in `JSONSearch.swift`):

```swift
/// True when this node directly matches: its key, or — for a scalar — its
/// rendered value. Containers match only via their key.
func nodeSelfMatches(key: String?, node: JSONNode, _ search: JSONSearch) -> Bool

/// True when this node, or any descendant, matches. Drives tree filtering.
func subtreeContainsMatch(key: String?, node: JSONNode, _ search: JSONSearch) -> Bool
```

Scalar value text for matching uses the same literal as the tree leaf renders
(e.g. number literal as stored, `true`/`false`, `null`, raw string contents
without surrounding quotes) so what the user sees is what they search.
`nodeSelfMatches` must mirror `JSONTreeRow.keyValueText` exactly — treat that
method as the source of truth for each scalar's rendered form.

Note a deliberate consequence of per-view fit: the **text** view searches the
serialized `pretty` string where strings *are* quoted, while the **tree**
searches unquoted scalar contents. A query containing a `"` can therefore match
in Text but not Tree. This is expected, not a bug.

### State in `JsonTool`

```swift
@State private var query = ""
@State private var isRegex = false
@State private var filterTree = false
@State private var currentMatch = 0   // index into text-view match list
```

- `search` is derived: `JSONSearch(query: query, isRegex: isRegex)`.
- `currentMatch` resets to 0 whenever the match list can change: `query`,
  `isRegex`, `indent`, **and `input`/`pretty`** (a history seed load via
  `applySeed` replaces `input`, re-flowing `pretty` and invalidating ranges).
  Simplest: reset whenever `pretty` changes.
- Search state is shared across views, so it persists when toggling Text/Tree.
- Contextual controls switch on the existing `view` string (`"text"`/`"tree"`),
  the same gate `outputBody` already uses.

## Behavior detail

### Text view (highlight + jump)

1. Start from the existing `jsonAttributed(pretty, t)`.
2. Overlay `.backgroundColor` for each range in `search.ranges(in: pretty)`:
   all matches use `t.searchHit`; the current match uses `t.searchActive`.
3. `CodeTextView` gains an optional `scrollTo: NSRange?`; in `updateNSView` it
   calls `scrollRangeToVisible(_:)` and `showFindIndicator(for:)` for that range.
   **Watch the existing early-return guard** (`textStorage.isEqual(to:)` skips
   work when attributed content is unchanged) — the scroll/indicator call must
   not be swallowed when only `scrollTo` changes. Stepping next/prev does change
   the attributed string (the `searchActive` background moves), but the scroll
   must fire on the `scrollTo`-changed path independently of the content guard.
4. Header shows `currentMatch+1 / total`; up/down chevrons step `currentMatch`
   with wrap-around. No matches → `0/0`, nothing highlighted.

### Tree view (highlight + filter)

`JSONTreeRow` receives `search` and `filterTree`:

- **Highlight:** row paints a background when `nodeSelfMatches` is true.
- **Filter (on):** a child is rendered only when `subtreeContainsMatch` is true;
  any node whose subtree contains a match is force-opened so matches are visible
  (overrides the default depth-based `open`).
- Filter on with zero matches anywhere → `EmptyHint` with `searchNoMatches`.

Match computation runs only when `search.isActive`, so inactive search costs
nothing. Worst case (filter over very large JSON) recomputes `subtreeContainsMatch`
per row — acceptable for typical developer payloads, and upgradeable later to a
single precomputed annotated tree if it ever becomes a bottleneck. **Known
tradeoff, recorded here rather than pre-optimized.**

## UI & components

- New compact **`SearchField`** in `DevKitComponents.swift`: a styled text field
  with an inline clear button, matching the app's existing control look. Shows a
  danger-colored state when `hasRegexError`.
- Placed in the result pane header `right:` area, beside the `Segmented`
  Text/Tree control.
- Contextual inline controls:
  - `n/total` count + up/down chevrons (text view).
  - `.*` regex toggle (both views).
  - filter toggle (tree view only).
- The header is already busy (Segmented + indent `MonoPicker` + `CopyBtn`).
  Keep the field compact; if it crowds on narrow widths, the contextual controls
  are the first to wrap. (Fallback if needed: a slim search strip at the top of
  the output body — not expected to be necessary.)

## Theme

Two new `ThemeTokens` authored in **oklch** for both dark and light themes:

- `searchHit` — subtle highlight for all matches.
- `searchActive` — stronger highlight for the current match (text view).

Must read legibly under existing syntax-highlight foreground colors in both themes.

## Localization

New compile-checked `Strings` fields, filled for **both** `.vi` and `.en`:

- `searchPlaceholder` — e.g. "Search…" / "Tìm…"
- `searchFilter` — filter toggle label/tooltip
- `searchNoMatches` — empty-result hint
- `searchRegexError` — invalid-regex indicator text/tooltip

Deliberately **not** localized (per existing convention for technical labels):
the `.*` regex toggle label and the `n/total` match count.

## Error handling & edge cases

- **Invalid regex:** `regex == nil` → `hasRegexError`, search inactive, field
  shows danger state, no highlight/filter, no crash.
- **Empty query:** inactive; no highlight, no filter, all controls idle.
- **No matches:** text view `0/0`, nothing highlighted; tree filter shows
  `searchNoMatches`.
- **Indent change:** re-flows `pretty`; ranges recomputed, `currentMatch` clamped/reset.
- **Invalid JSON:** search field hidden/disabled — there is no valid output to search.
- **History push** (on input blur) is unaffected by search state.

## Testing (`XoaiUtilityTests`, Swift Testing)

- `matches`: case-insensitive substring; regex pattern; invalid regex →
  `hasRegexError == true`, `isActive == false`.
- `ranges(in:)`: correct count and locations, including adjacent matches.
- `nodeSelfMatches`: matches on keys vs scalar values; container matches only via key.
- `subtreeContainsMatch`: nested objects/arrays, match deep in a subtree, no-match case.

## Files

**New**
- `XoaiUtility/JSONSearch.swift` — matcher + tree helpers.
- Tests in `XoaiUtilityTests` for the above.

**Modified**
- `XoaiUtility/JsonTool.swift` — search state, header search field, text-view
  highlight overlay + jump, pass search into tree, `JSONTreeRow` highlight/filter.
- `XoaiUtility/CodeTextView.swift` — `scrollTo: NSRange?` support.
- `XoaiUtility/DevKitComponents.swift` — `SearchField` (and inline nav/toggles as needed).
- `XoaiUtility/Theme.swift` — `searchHit` / `searchActive` tokens (dark + light).
- `XoaiUtility/Localization.swift` — new `Strings` fields for `.vi` and `.en`.
