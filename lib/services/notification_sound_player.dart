import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../data/models/notification_sound_option.dart';
import 'driver_preferences_service.dart';

/// Plays the driver's chosen notification sound (assets/notification_sounds/) at their saved
/// volume, for foreground-triggered alerts and the Settings "Preview" button. This is the only
/// layer that can actually honor a volume preference - the OS push-notification channel used for
/// background/closed-app delivery has no per-app volume control (AndroidNotificationChannel/
/// UNNotificationSound both play at the device's own notification-volume setting, which no public
/// API lets an app override). A fresh AudioPlayer per call avoids any state leaking between a
/// rapid foreground alert and a driver tapping Preview moments later.
class NotificationSoundPlayer {
  NotificationSoundPlayer._();

  static final instance = NotificationSoundPlayer._();

  Future<void> play({String? soundId, double? volume}) async {
    await DriverPreferencesService.instance.load();
    final prefs = DriverPreferencesService.instance.preferences.value;
    final option = notificationSoundById(soundId ?? prefs.notificationSoundId);
    final effectiveVolume = volume ?? prefs.notificationVolume;
    final player = AudioPlayer();
    try {
      await player.setVolume(effectiveVolume.clamp(0.0, 1.0));
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(
        AssetSource(option.assetPath.replaceFirst('assets/', '')),
      );
    } finally {
      unawaited(player.onPlayerComplete.first.then((_) => player.dispose()));
    }
  }
}
