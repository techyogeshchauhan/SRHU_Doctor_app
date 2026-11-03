/// Feature switches for modules that are built but not currently offered.
/// Pure Dart.
library;

/// Case History (structured / free-text case entry → guided multi-STW
/// assessment). Temporarily hidden on every platform: the toolbar button and
/// the chat "Open as guided case" chip are not shown, and `/case` links
/// redirect to Home. The module itself is untouched — set to `true` to bring
/// it back.
const bool kCaseHistoryEnabled = false;
