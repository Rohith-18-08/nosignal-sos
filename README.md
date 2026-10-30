# 📡 NoSignal SOS

**When disasters knock out mobile networks, people can't call for help. NoSignal SOS turns every
smartphone into a relay: an SOS message hops from phone to phone over Bluetooth and Wi-Fi Direct,
with no internet or SIM signal, until it reaches any phone that is online. Then it appears instantly
on a rescue team's live map.**

## How it works

```
 [Phone A]  ~~Bluetooth/Wi-Fi Direct~~>  [Phone B]  ~~~~~~~~~~>  [Phone C]  --internet-->  [Firebase]  -->  [Rescue map]
  victim,                                 relay,                  gateway,                     cloud           dashboard
  no network                              no network              has network
      ^                                                                  |
      +---------------- "Rescue team notified ✅" (ack hops back) ------+
```

1. **Mesh:** every phone *advertises* itself and *discovers* others at the same time, using Google's
   Nearby Connections API (Bluetooth + BLE + Wi-Fi Direct, chosen automatically).
2. **Store-and-forward:** each phone keeps every SOS it hears and sends it to every neighbour,
   including phones that arrive later.
3. **No loops:** each SOS has a unique ID, and a phone ignores IDs it has already seen.
4. **Route tracking:** each phone adds its name to the message's path, so rescuers can see how it travelled.
5. **Gateway:** any phone with internet uploads the SOS to the cloud.
6. **Acknowledgement:** after a successful upload, an "ack" spreads back through the mesh, so the victim
   knows help has been notified.

## Try it
**Install the app:** download `NoSignal_SOS.apk` from this repository's **Releases** page (right-hand side on GitHub),
open it on an Android phone (Android 8+) and allow the install. Then allow Bluetooth, Location and Nearby devices.

**Rescue dashboard:** open `dashboard/index.html` in Chrome. It connects to the live database automatically.

**Quick test with 2 phones:**
1. Phone A: airplane mode, then turn Bluetooth and Wi-Fi back on (not connected to any network). Location on.
2. Phone B: mobile data on.
3. Open the app on both with different names and tap **Join the mesh**. Wait until each shows the other.
4. On Phone A, tap **SOS** and send. It appears on the dashboard, and Phone A shows "Rescue team notified".

**Build from source:** install Flutter and Android Studio, then in this folder run:
```
powershell -ExecutionPolicy Bypass -File setup.ps1
flutter build apk --release
```
Full step-by-step instructions are in [SETUP.md](SETUP.md).

## Project files
| File | What it does |
|---|---|
| `lib/main.dart` | Screens: start screen, SOS button, message list, SOS form |
| `lib/mesh_service.dart` | **The core:** discovery, connections, relaying, acks, uploads |
| `lib/sos_message.dart` | What an SOS message contains |
| `lib/cloud_service.dart` | Uploads to Firebase Realtime Database over HTTPS |
| `lib/location_service.dart` | GPS (works offline) |
| `dashboard/index.html` | Live rescue map for the projector |

## Tech stack
Flutter (Dart) · Google Nearby Connections · GPS · Firebase Realtime Database · Leaflet maps

## Judges' cheat sheet (questions you'll likely get)

**"How do phones talk without internet?"**
Google's Nearby Connections API. It uses Bluetooth to find nearby phones and switches to Wi-Fi Direct
for faster transfer. No router, SIM or internet is needed.

**"What's the range?"**
Roughly 10–100 m per hop, depending on obstacles. The range multiplies with every phone in the chain.
In a crowded area like a city or a relief camp, there are many phones to hop through.

**"Why doesn't the message loop forever?"**
Every SOS has a unique ID. A phone that has already seen an ID drops it.

**"What if no phone nearby has internet?"**
The message waits on every phone that has it (store-and-forward). When any of those people walk into
coverage, or a rescue team arrives with a connected phone, it uploads automatically.

**"What about battery?"**
The current version runs continuously for the demo. Future plan: a low-power mode that scans in bursts.

**"Does it work on iPhone?"**
Not yet. iOS restricts this kind of background peer-to-peer networking. Android has about 95% market share in India.

**"Is it secure? Can someone send fake SOS?"**
In the prototype, any phone can relay, which is intended: in a disaster, reach matters most.
Future plan: signed messages and spam limits per device.

**"How is this different from existing solutions?"**
Satellite SOS needs expensive phones, and radios need special hardware. This works on phones people already own.

## Future scope
- Low-power mode and background operation
- Offline maps on the victim's phone
- AI triage that ranks SOS messages by urgency for rescuers
- Messages in Indian languages, and voice SOS
- Connecting to LoRa radio devices for kilometre-range hops
