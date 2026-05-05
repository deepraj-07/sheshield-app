# SheShield SOS Test Checklist

Use this checklist after Firebase, SMS, Bluetooth, and camera permissions are configured.

## Firebase Setup
- [ ] `firebase_options.dart` points to your real Firebase project.
- [ ] `google-services.json` is present in `android/app/`.
- [ ] Authentication with Email/Password is enabled.
- [ ] Firestore is enabled.
- [ ] Storage is enabled.
- [ ] Cloud Messaging is enabled.
- [ ] Firestore smoke test writes a document to `setup_checks/firebase_smoke_test`.

## SOS Flow
- [ ] Press and hold the SOS button for 3 seconds.
- [ ] Confirm SOS state changes to active.
- [ ] Confirm GPS location is logged.
- [ ] Confirm SMS dispatch is attempted for each emergency contact.
- [ ] Confirm video recording starts without blocking the UI.
- [ ] Confirm video file is produced and uploaded.
- [ ] Confirm SHA-256 hash is generated.
- [ ] Confirm evidence metadata is written to Firestore.
- [ ] Confirm notification tokens are fetched and push dispatch is attempted.
- [ ] Confirm bracelet alert commands are sent over Bluetooth.
- [ ] Confirm duplicate SOS taps are ignored while active.

## Bluetooth Checks
- [ ] ESP32 sends `SOS\n` and triggers the global SOS callback.
- [ ] ESP32 sends `SHAKE\n` and logs the event.
- [ ] ESP32 sends `STEALTH\n` and activates stealth mode.
- [ ] Bluetooth reconnects automatically after disconnect.

## Debug Logs To Watch
- `SOS` step logs: start, GPS, SMS, video, evidence, notification, bracelet.
- `SMS` logs: per-contact success/failure and retries.
- `GPS` logs: location fetch and reverse geocode.
- `VIDEO` logs: recording start, file ready, timeout handling.
- `FIREBASE` logs: hash/upload/save/notification queue.
- `BT` logs: incoming ESP32 command and reconnect attempts.

## Manual Verification
- [ ] Firestore contains a `sos_events/{eventId}` document.
- [ ] Firestore contains an `evidence/{incidentId}` document.
- [ ] Device token is stored in Firestore.
- [ ] Notifications are received on at least one registered device.
