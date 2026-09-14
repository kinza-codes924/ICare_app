/// Parsing server timestamps into the viewer's own timezone.
///
/// The backend stores and returns UTC ("2026-09-14T17:40:28.260Z"), and
/// `DateTime.parse` keeps a Z-suffixed string in UTC. Formatting that directly
/// prints UTC to the user: a comment posted at 10:40 PM in Pakistan showed as
/// 5:40 PM, five hours adrift, on a screen where the clock above it read the
/// real time. `.toLocal()` is the whole fix, and this exists so it is not left
/// off again at the next call site.
library;

/// Parse a server timestamp into local time.
///
/// Accepts a String, a DateTime, or null. Returns null when there is nothing
/// usable, so callers decide what to show for a missing date rather than
/// silently getting "now".
DateTime? parseServerTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();

  final s = raw.toString().trim();
  if (s.isEmpty) return null;

  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;

  // A timestamp with no zone marker is still UTC — that is what the backend
  // writes — so treat it as such before converting.
  if (!parsed.isUtc && !s.contains('+') && !s.endsWith('Z')) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    ).toLocal();
  }
  return parsed.toLocal();
}

/// Same, with a fallback for screens that must render something.
DateTime parseServerTimeOr(dynamic raw, DateTime fallback) =>
    parseServerTime(raw) ?? fallback;
