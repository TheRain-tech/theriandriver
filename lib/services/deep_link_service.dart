import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../core/localization/driver_copy.dart';
import '../router/route_names.dart';
import 'auth_service.dart';

/// The invitation token inside a shared fleet-invitation link, or null when [uri] is not one.
///
/// Two forms carry the same token and end at the same claim screen:
///  - `https://<host>/fleet-invite?token=...` (the link a Fleet Owner shares; opens the app directly once
///    the domain is verified for Android App Links, otherwise via the web page's "Open in TheRain Driver"),
///  - `therain-driver://app/fleet-invite?token=...` (the app's own scheme, no domain needed).
/// The token is only ever a candidate here: the server verifies it (preview / claim) before anything happens.
String? fleetInviteTokenFrom(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http' && scheme != 'therain-driver') {
    return null;
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final isInvitePath =
      (segments.isNotEmpty && segments.last == 'fleet-invite') ||
      // therain-driver://fleet-invite?token=... (host form)
      (scheme == 'therain-driver' && uri.host == 'fleet-invite');
  if (!isInvitePath) return null;
  final token = uri.queryParameters['token']?.trim();
  if (token == null || !RegExp(r'^[A-Za-z0-9_-]{16,256}$').hasMatch(token)) {
    return null;
  }
  return token;
}

/// Turns a tapped invitation link into the claim screen with the token already filled in.
///
/// A link that arrives while the app is starting is kept (see [takePendingInviteToken]) and picked up by
/// the startup screen once it knows nobody is signed in; a link that arrives while the app is running
/// opens the claim screen straight away. A driver who is already signed in is told to sign out first
/// rather than silently switching accounts.
class DeepLinkService {
  DeepLinkService._();

  static final instance = DeepLinkService._();

  StreamSubscription<Uri>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingInviteToken;

  /// The invitation token from a link that opened the app, handed out once.
  String? takePendingInviteToken() {
    final token = _pendingInviteToken;
    _pendingInviteToken = null;
    return token;
  }

  Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    if (_subscription != null) return;
    _navigatorKey = navigatorKey;
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) handle(initial);
      _subscription = links.uriLinkStream.listen(
        handle,
        onError: (Object _) {},
      );
    } catch (_) {
      // Links are a convenience: a platform without the plugin (or a failure to read one) never stops the
      // app - the driver can still paste the code by hand.
    }
  }

  void handle(Uri uri) {
    final token = fleetInviteTokenFrom(uri);
    if (token == null) return;
    _pendingInviteToken = token;
    _openIfReady();
  }

  void _openIfReady() {
    final navigator = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    // Still starting: the startup screen will take the pending token itself.
    if (navigator == null || context == null) return;
    // The Navigator's own context sits above every route, so ask the navigator which route is on top
    // (popUntil with an always-true test pops nothing; it only lets us look).
    String? route;
    navigator.popUntil((current) {
      route = current.settings.name;
      return true;
    });
    if (route == null || route == RouteNames.startup) return;

    final token = takePendingInviteToken();
    if (token == null) return;
    if (AuthService.instance.currentUserId != null) {
      final copy = DriverCopy.current;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            copy.t(
              'This invitation is for a new driver account. Sign out first to use it.',
              "Cette invitation est destinée à un nouveau compte chauffeur. Déconnectez-vous d'abord pour l'utiliser.",
            ),
          ),
        ),
      );
      return;
    }
    navigator.pushNamedAndRemoveUntil(
      RouteNames.claimInvitation,
      (route) => route.settings.name == RouteNames.login || route.isFirst,
      arguments: {'token': token},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
