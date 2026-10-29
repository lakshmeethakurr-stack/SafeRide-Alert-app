# SafeRide Alert — Android MVP Starter

This is a Flutter starter project for an Android emergency SOS app. It is a **prototype**, not a certified emergency-response system.

## Included
- Flutter SOS home screen
- Location permission and current GPS coordinates
- SMS composer with a Google Maps location link (the user reviews/sends it)
- Demo countdown UI for a possible accident
- Emergency contact settings stored locally on the device
- Firestore security rules starter
- Setup and testing instructions

## Not yet production-ready
- Automatic accident detection is a demo trigger only; it does not continuously monitor sensors.
- SMS is opened for the user to send; the app does not silently send SMS.
- No backend delivery guarantee, emergency-service integration, or validated crash-detection model.
- Local contact storage is for the MVP only. Review privacy and secure storage before release.

## Requirements
Install Flutter SDK and Android Studio, including Android SDK/platform tools. Check:
```bash
flutter doctor
```

## Run
1. Extract this folder.
2. In the project folder run:
   ```bash
   flutter pub get
   flutter run
   ```
3. Test on a real Android phone. Location permissions and SMS app behavior vary by device.

## Customize emergency contact
Open the app's **Contacts** tab and enter a trusted contact number including country code, e.g. `+91...`. Use only a number you own or whose owner has consented to testing.

## Android permissions
The required location permissions are included in `android/AndroidManifest.xml`.
This MVP intentionally does **not** request background location. Background sensor/location behavior needs a separate Android foreground-service design and policy review.

## Next steps for production
1. Add Firebase Authentication and Firestore with strict user-scoped rules.
2. Build a backend alert service and delivery tracking.
3. Add a validated sensor detection pipeline and false-positive review.
4. Implement user consent, privacy policy, deletion, rate limiting, abuse prevention, monitoring, and incident handling.
5. Complete Google Play policy review and a controlled pilot.

## Safety
Do not rely on this prototype as your only way to request emergency help. It may fail due to permissions, battery restrictions, GPS/network issues, or unavailable SMS apps.
