# URL Decode — Key/Value Table View

**Date:** 2026-06-07
**Status:** Approved
**Tool affected:** URL encode/decode (`UrlTool`)

## Problem

The URL tool decodes a string as one flat blob. For **form-encoded bodies**
(`application/x-www-form-urlencoded`) — `key=value` pairs joined by `&`, each
value percent-encoded — this is hard to read. Example real payload:

```
feature_ids=%5b%22feature_drip_7d%22%2c%22feature_drip_14d%22%2c%22feature_drip_30d%22%5d&ab_attributes=%7b%22platform%22%3a%22OSXEditor%22%2c%22client_version%22%3a%221.0.0%22%7d&unique_nonce=b6d3dfad-9736-4722-b19f-5f5409a6cd0e&ts=1775036682&signature=sXEL73a3BTaW1FU8_Ozyud1WcDRiwXW4zfWAiCjdvqU%3d
```

decodes (per pair) to:

| Key | Value |
|---|---|
| `feature_ids` | `["feature_drip_7d","feature_drip_14d","feature_drip_30d"]` |
| `ab_attributes` | `{"platform":"OSXEditor","client_version":"1.0.0"}` |
| `unique_nonce` | `b6d3dfad-9736-4722-b19f-5f5409a6cd0e` |
| `ts` | `1775036682` |
| `signature` | `sXEL73a3BTaW1FU8_Ozyud1WcDRiwXW4zfWAiCjdvqU=` |

The user wants an option, in **decode** mode, to view the result as a key/value
table.

## Key insight

The table must **split on `&` and `=` first, then percent-decode each key and
value separately**. Decoding the whole string first (what the current tool does)
mangles the structure — `&` and `=` inside encoded values would be confused with
separators. So the table parses the **raw input**, not the decoded `result.value`.

## Design

### 1. Parsing engine (pure, testable)

A new pure helper in `UrlTool.swift`, alongside `URLCodec`:

```swift
struct FormPair: Identifiable { let id: Int; let key: String; let value: String }

enum FormCodec {
    /// Split a form-encoded body (or a URL's query) into decoded key/value pairs.
    static func pairs(_ s: String) -> [FormPair]
}
```

Behavior:

- If the string contains `?`, parse only the substring **after the first `?`**,
  and drop any `#fragment`. Handles both a raw form body and a full URL pasted in.
- Split on `&`. Skip empty segments (e.g. from a trailing `&`).
- Split each segment on the **first** `=` only. No `=` → value is empty string.
  Values containing a literal `=` (e.g. base64 padding) stay intact.
- For each key and value: replace `+` → space, then percent-decode (form
  semantics). If a piece has invalid percent-encoding, fall back to the raw
  piece (do not drop the row).
- `id` is the pair's index, for stable `Identifiable` / `ForEach`.

### 2. UI — output pane

URL gets a dedicated `UrlOutputPane` so the shared `CodecOutputPane` stays clean
for Base64 (which never needs a table).

- **Decode mode only:** a `Segmented` control in the pane header — `Text` /
  `Table`. In **encode** mode the control is hidden and the pane behaves exactly
  as today.
- **Text view:** unchanged — current `OutputText` + count footer.
- **Table view:** renders `FormCodec.pairs(input)` as themed rows — two columns
  (Key / Value), monospaced, using the existing oklch theme tokens and
  alternating row tint. Keys auto/fixed width; values wrap or scroll. Empty
  input → existing `EmptyHint`.
- **Copy button:** unchanged — copies the full decoded text (`result.value`).
  The table is a *view* of the data, not a separate copy target.

New state: `@State private var outputView = "text"` in `UrlTool`. The table view
reads the **raw `input`** (per-pair decode is the point), not `result.value`.

### 3. Localization

Four new fields in `Strings` (`Localization.swift`), filled in both `.vi` and
`.en` (a missing translation is a build error):

| Field | EN | VI |
|---|---|---|
| `urlViewText` | Text | Văn bản |
| `urlViewTable` | Table | Bảng |
| `tableKey` | Key | Khóa |
| `tableValue` | Value | Giá trị |

### 4. Testing

Swift Testing suite in `XoaiUtilityTests` for `FormCodec.pairs`:

- The real payload above → 5 pairs with correctly decoded JSON/uuid/signature
  values.
- `+` decodes to space.
- A segment with no `=` → empty value.
- Empty input → `[]`.
- A full `https://…?a=1&b=2#frag` URL → parses just `a`/`b`; fragment dropped.
- A value with an encoded `=` (`%3d`) → `=` preserved in the value.

## Out of scope (YAGNI)

- Pretty-printing JSON values inside cells (show raw decoded string).
- Per-row copy / copy-as-TSV.
- A table view in encode mode or in the Base64 tool.
- URL anatomy breakdown (scheme/host/path rows).
