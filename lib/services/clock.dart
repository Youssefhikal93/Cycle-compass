/// Overridable clock used everywhere the app needs the current moment.
///
/// Production code leaves this as [DateTime.now]. Tests — especially the
/// golden screenshot tests, whose rendered output depends on the current
/// date — pin it to a fixed value so results stay reproducible.
DateTime Function() appNow = DateTime.now;
