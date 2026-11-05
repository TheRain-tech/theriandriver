/// The 10-sound pack bundled at assets/notification_sounds/ (see that folder's README.txt -
/// peak-normalized to ~-3 dBFS, no further loudness fix needed unlike the original single-sound
/// assets this session already boosted). id is the stable value persisted to preferences - never
/// rename an existing id without a migration, or every driver who already picked that sound
/// silently reverts to the default.
class NotificationSoundOption {
  const NotificationSoundOption({
    required this.id,
    required this.assetFileName,
    required this.labelEn,
    required this.labelFr,
  });

  final String id;
  final String assetFileName;
  final String labelEn;
  final String labelFr;

  String get assetPath => 'assets/notification_sounds/$assetFileName';

  String label(bool french) => french ? labelFr : labelEn;
}

const List<NotificationSoundOption> kNotificationSoundOptions = [
  NotificationSoundOption(
    id: 'message_ping',
    assetFileName: '01_message_ping.mp3',
    labelEn: 'Message Ping',
    labelFr: 'Bip de message',
  ),
  NotificationSoundOption(
    id: 'notification_bell',
    assetFileName: '02_notification_bell.mp3',
    labelEn: 'Notification Bell',
    labelFr: 'Cloche de notification',
  ),
  NotificationSoundOption(
    id: 'digital_ride_alert',
    assetFileName: '03_digital_ride_alert.mp3',
    labelEn: 'Digital Ride Alert',
    labelFr: 'Alerte course numérique',
  ),
  NotificationSoundOption(
    id: 'double_chime',
    assetFileName: '04_double_chime.mp3',
    labelEn: 'Double Chime',
    labelFr: 'Double carillon',
  ),
  NotificationSoundOption(
    id: 'priority_alert',
    assetFileName: '05_priority_alert.mp3',
    labelEn: 'Priority Alert',
    labelFr: 'Alerte prioritaire',
  ),
  NotificationSoundOption(
    id: 'arrival_bell',
    assetFileName: '06_arrival_bell.mp3',
    labelEn: 'Arrival Bell',
    labelFr: "Cloche d'arrivée",
  ),
  NotificationSoundOption(
    id: 'smart_click',
    assetFileName: '07_smart_click.mp3',
    labelEn: 'Smart Click',
    labelFr: 'Clic intelligent',
  ),
  NotificationSoundOption(
    id: 'success_tone',
    assetFileName: '08_success_tone.mp3',
    labelEn: 'Success Tone',
    labelFr: 'Tonalité de succès',
  ),
  NotificationSoundOption(
    id: 'triple_alert',
    assetFileName: '09_triple_alert.mp3',
    labelEn: 'Triple Alert',
    labelFr: 'Triple alerte',
  ),
  NotificationSoundOption(
    id: 'emergency_signal',
    assetFileName: '10_emergency_signal.mp3',
    labelEn: 'Emergency Signal',
    labelFr: "Signal d'urgence",
  ),
];

// Driver app default differs deliberately from the rider/fleet default: ride-request alerts are
// the primary thing a driver must never miss, so "Priority Alert" (a more attention-grabbing
// tone than the generic message ping) is the out-of-the-box choice here.
const String kDefaultNotificationSoundId = 'priority_alert';

NotificationSoundOption notificationSoundById(String id) =>
    kNotificationSoundOptions.firstWhere(
      (option) => option.id == id,
      orElse: () => kNotificationSoundOptions.first,
    );
