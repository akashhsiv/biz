/// A whole-number quantity should show as "1", not "1.0" (the default `double.toString()` output) —
/// while still letting the user type a fractional quantity like "1.5" for a kg/ltr/meter item when
/// they actually need one. Centralized here since it was already being reimplemented slightly
/// differently in more than one place.
String formatQuantity(double q) => q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toString();
