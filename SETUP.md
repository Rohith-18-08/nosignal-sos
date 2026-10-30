# NoSignal SOS: Setup Guide (Windows)

Allow about 1–2 hours the first time, mostly downloads. If any step shows an error, copy the
whole error message and paste it to Claude.

---

## Step 1: Install Android Studio
1. Download it from https://developer.android.com/studio and install it with the default options.
2. Open Android Studio once and let the **Setup Wizard** finish. It downloads the Android SDK.
3. In Android Studio, go to **More Actions → SDK Manager → SDK Tools** tab, tick
   **Android SDK Command-line Tools**, and click **Apply**.

## Step 2: Install Flutter
1. Go to https://docs.flutter.dev/get-started/install/windows/mobile and download the Flutter SDK zip.
2. Extract it to `C:\flutter`. Don't use `Program Files`.
3. Add Flutter to your PATH: press Start, type **"environment variables"**, open
   **Edit environment variables for your account**, select **Path → Edit → New**, add `C:\flutter\bin`, then click OK.
4. Close and reopen PowerShell, then run:
   ```
   flutter doctor
   flutter doctor --android-licenses
   ```
   Type `y` to accept all the licenses. Ignore any warnings about Visual Studio or Chrome; you don't need them.

## Step 3: Prepare the 3 phones
On **each** Android phone:
1. **Settings → About phone →** tap **Build number** 7 times. This turns on Developer options.
2. **Settings → Developer options →** turn on **USB debugging**.
3. Connect the phone to the laptop by USB, then tap **Allow** on the phone's popup.

## Step 4: Run the setup script
Open PowerShell in the `nosignal_sos` folder and run:
```
powershell -ExecutionPolicy Bypass -File setup.ps1
```

## Step 5: Create the free Firebase database (where SOS messages land)
1. Go to https://console.firebase.google.com and click **Create a project** (name: `nosignal-sos`). You can turn Analytics off.
2. In the left menu, choose **Build → Realtime Database → Create Database**, pick the closest location,
   and choose **Start in test mode**.
3. Copy the database URL shown at the top. It looks like `https://nosignal-sos-default-rtdb....firebasedatabase.app`.
4. Paste it into `lib/config.dart` in place of `YOUR-FIREBASE-URL`.
5. Open `dashboard/index.html` in Chrome, click **⚙ Settings**, paste the same URL, and click **Save & connect**.
   The pill should turn green: **● Live**.

> ⚠️ Test mode lets anyone read and write the database, which is fine for a demo.
> Delete the Firebase project after the hackathon.

## Step 6: Install the app on all 3 phones
Build one installable file:
```
flutter build apk --release
```
The file is created at `build\app\outputs\flutter-apk\app-release.apk`. Copy it to each phone
(USB, Google Drive or Bluetooth), tap it, and allow "install unknown apps".

*(Alternative while testing: with one phone plugged in, run `flutter run` to install it and see live logs.)*

---

## 🎬 Demo setup (rehearse this at least 3 times!)

| Phone | Name in app | Network | "Only connect to" |
|---|---|---|---|
| Victim | `Phone-A` | ✈ Airplane mode, then turn **Bluetooth ON** and **Wi-Fi ON** (not joined to any network) | `Phone-B` |
| Relay | `Phone-B` | Same as Phone-A | `Phone-A, Phone-C` |
| Gateway | `Phone-C` | Mobile data **ON** | `Phone-B` |

**Location must be ON** on all phones. Before the demo, open Google Maps once so GPS has a fix.

1. Open the app on all 3 phones, enter the names, fill in "Only connect to", and tap **Join the mesh**.
2. Wait until Phone-B shows both `Phone-A` and `Phone-C` as chips (10–30 seconds).
3. Put the dashboard on the projector.
4. On Phone-A, tap **SOS**, choose "Trapped" and "Injured", set 3 people, and tap **SEND SOS**.
5. The dashboard beeps, the map flies to the pin, and the route shows **Phone-A → Phone-B → Phone-C → ☁️**.
6. Show Phone-A to the judges: **"Rescue team notified ✅"**, even though it has no internet.

**Why "Only connect to"?** On stage all phones are within Bluetooth range, so A would reach C directly.
This setting simulates distance. Explain it honestly: *"In a real disaster, the phones would be hundreds
of metres apart; here we force the chain."*

**Backup plan:** if something fails live, click **＋ Simulate SOS** on the dashboard (it's clearly labelled
SIMULATED). Also record a screen video of a working run the day before.

## Troubleshooting
| Problem | Fix |
|---|---|
| Phones never connect | Check that Bluetooth and Location are ON, permissions were allowed, and the names are different. Restart the app on both phones. |
| Connected, but the dashboard shows nothing | Check that Phone-C really has internet, the Firebase URL is correct in both places, and the database is in test mode. |
| SOS on the dashboard has no pin | GPS had no fix. Go near a window or open Google Maps first. |
| Build error mentioning Gradle, Kotlin or minSdk | Paste the error to Claude. |
