<div align="center">

<img src="assets/icon/app_icon.png" width="120" alt="Flex" />

# FLEX

**push-ups, counted by your face.**

no sensors on your body, no manual taps, no server.
place the phone on the floor, get down, and go.

</div>

---

## how it works

Flex never touches an accelerometer or a tap button to count a rep. Instead:

1. you set the phone face-up on the floor
2. the TrueDepth camera locks onto your face
3. every time your head dips toward the screen and comes back up, that's a rep

The counting logic lives entirely in [`RepCounter`](lib/features/workout/rep_counter.dart) — a small state machine driven by the face-to-camera distance ARKit reports on every frame. It has no idea it's counting push-ups; it just watches a number go down, then up, past two thresholds, with a minimum rep duration to reject noise. That separation is why the counter is unit-tested without a camera, a phone, or a body anywhere near it.

```
        distance
           │
   camera ─┤
           │      ╱‾‾╲          ╱‾‾╲
           │     ╱    ╲        ╱    ╲
     floor ─┴────╱──────╲──────╱──────╲──── time
                 down    up   down    up
                  └── one rep ──┘
```

## what it tracks

Every set logs reps, duration, rest before the set, and per-rep timing — enough to compute averages later without recomputing from raw frames. A streak counter watches for at least one workout a day; miss a day and it resets, same rules as everyone expects from this kind of thing by now.

Want to look at your own numbers instead of trusting a dashboard? The database is a plain SQLite file on your device — `sqflite`, no ORM magic on top.

## your data leaves only if you tell it to

Flex doesn't have a server. There is no account, no sync, no analytics call fired off in the background. Everything lives in `flex.db` on your phone until you explicitly export it.

Export produces a single `.flexbak` file: your full workout history, AES-256-GCM encrypted. That's not just for privacy — GCM's authentication tag means the app can tell if a single byte of that file changed after you exported it, whether by corruption or by hand. Import checks the tag before touching your database; if it doesn't match, nothing gets written and you get told the file was tampered with. Move the file to a new phone, import it there, done.

```
lib/core/export/backup_codec.dart   — encode/decode + the tamper check
test/backup_codec_test.dart         — proves a flipped byte gets rejected
```

## design

Built entirely on iOS 26's Liquid Glass language: translucent layers, backdrop blur, specular edges, no color beyond black and white. No screenshots here — the interface is the screenshot. Run it.

## running it

```bash
flutter pub get
flutter test        # counter logic, streaks, backup encryption — all offline, no device needed
flutter run         # needs a physical iPhone with a TrueDepth camera; the simulator has no depth sensor
```

TrueDepth means iPhone X or later. There's no fallback path for older hardware — the whole product is the face tracking, so we didn't build a worse version around a tap-to-count button.

## structure

```
lib/
  app/theme/       liquid glass primitives, colors, type scale
  core/             models, sqlite layer, streak math, backup codec
  features/
    workout/        the rep counter + the camera session screen
    home/            today's count, this week's strip
    stats/           streak grid, per-rep and per-rest averages
    share/           renders the stat card you actually share
    settings/        reminders, export/import, wipe
ios/Runner/
  FaceTracker.swift  ARKit session, exposed to Dart over a platform channel
```

## license

MIT. See [LICENSE](LICENSE). Do whatever you want with it.
