/// Strips a leading Google Plus Code (Open Location Code, e.g. "X529+MWC ") from a geocoded
/// address before it's shown to a driver/rider. Google's own formatted_address for a location in
/// an area with sparse civic addressing (common in parts of Cameroon) is often genuinely nothing
/// but a plus code - this never fabricates a better name, it only removes an unreadable token
/// when real text follows it, leaving the rest of Google's own address untouched. Mirrors
/// therian/lib/core/utils/address_formatter.dart (same fix, two separate apps).
class AddressFormatter {
  // Plus Codes use Open Location Code's base-20 alphabet (digits 2-9 and letters
  // 23456789CFGHJMPQRVWX, excluding 0,1 and vowels to avoid accidental words) - a 4-6 char area
  // code, a '+', then a 2-3 char local code, e.g. "X529+MWC" or "8FVC9G8F+6X".
  static final RegExp _leadingPlusCode = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\s*',
    caseSensitive: false,
  );

  static String clean(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return trimmed;
    final withoutCode = trimmed.replaceFirst(_leadingPlusCode, '').trim();
    // If stripping the code left nothing (the address WAS only a plus code), keep the original -
    // showing an empty label would be worse than showing the one piece of location data Google
    // actually has for this spot.
    return withoutCode.isEmpty
        ? trimmed
        : withoutCode.replaceFirst(RegExp(r'^,\s*'), '');
  }
}
