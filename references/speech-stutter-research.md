# AVSpeechSynthesizer stutter and write(_:toBufferCallback:): research

Researched 2026-10-22 for Mnemit (iPhone 13 mini, iOS 26, el-GR). Confidence labels: measured, reported by several,
single report, my inference. Nothing here was measured on the Mnemit device. Apple Developer Forums threads sit behind a
verify-human wall that `oc`, curl and Tavily extract do not pass (threads 737685, 738048, 737468, 716424, 714984, 746735,
841198, 849627 not read; open them in a browser). Stack Overflow was read through Tavily extract, Apple docs as `.md` pages.

## 1. Known causes of stutter, choppy or cut-off speech

- iOS 26: no source found that describes stutter or crackling of AVSpeechSynthesizer on iOS 26.
- iOS 26.5.1, iPhone 17 Pro: occasional utterances are not spoken (an unspoken "1" lasts 0.1 s between didStart and didFinish,
  a spoken one 0.5 s) while the app toggles `duckOthers`; poster says older iOS versions did too; cause not established.
  https://forums.swift.org/t/avspeechsynthesizer-occasionally-doesnt-speak/87505 (2026-06-19). Single report.
- Apple Developer Forums tag listings (2026, snippets only): speech pauses on device lock despite an active background session
  (`usesApplicationAudioSession` default true); enhanced en-GB Daniel fails on macOS 26.6.2 Mac Catalyst with App Sandbox on.
  https://developer.apple.com/forums/tags/avaudiosession and /tags/speech. Single reports each.
- Stutter blamed on UI work was caused by the app calling `setCategory(.playAndRecord, [.defaultToSpeaker, .duckOthers])` and
  `setActive(true)` before every speak; removing both fixed it. https://stackoverflow.com/questions/38099904 (answer 2016-07-26).
  Single report.
- System speech with Siri (neural) voices drops out and goes silent in the Shortcuts "Speak Text" action after iOS 16, seen on
  iPhone 13 Pro and 14 Pro (same A15/A16 class as the 13 mini). Re-downloading voices did not help.
  https://www.reddit.com/r/shortcuts/comments/xjg91u (2022). Single report; shows system synthesis alone can drop out with no
  app code involved (my inference).
- Out of process: Apple says with `usesApplicationAudioSession = false` "the system creates a separate audio session" to manage
  speech. https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession (doc, 2026).
  The log tag `[AXTTSCommon] TTSPlaybackEnqueueFullAudioQueueBuffer` appears in the app's own console (SO 73716508 below), so the
  audio queue enqueue runs inside the client. No source found that names the speech daemon or says client load starves it.
  My inference: synthesis is a system service, playback is an AudioQueue in the app process; main-thread load can still delay
  enqueueing.
- Claim that `.spokenAudio` with the app session degrades quality on real devices and `usesApplicationAudioSession = false` plus
  `.default` mode fixes it: no measurements, ad for a paid library, doubtful "super-compact is the best tier" claim.
  https://medium.com/@info_4533/why-avspeechsynthesizer-sounds-terrible-on-real-iphones-eb4565862ea8 (2026-06-10). Single
  report, low trust; the switch is cheap to test.

## 2. write(_:toBufferCallback:) on iOS 17-26

- Apple documents only: "receive audio buffers to store or further process synthesized speech"; iOS 13+. The marker variant is
  iOS 16+. No buffer format, no end-of-stream rule are documented.
  https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:) (doc, 2026).
- Buffer format depends on the voice: Float32 for Siri/Premium, Int16 for compact (Maui/Vocalizer) voices on iOS 16/17.
  https://github.com/dlutton/flutter_tts/pull/632 (2026-05-10). Single report (PR text, unverified).
- Consistent with: on iOS 16 some voices came out right and others distorted with one forced file format
  (https://github.com/dlutton/flutter_tts/pull/435, 2023-11-10); on iOS 17 CAF output was noise until the file settings
  followed the voice, and enhanced/premium voices added in Settings worked
  (https://github.com/dlutton/flutter_tts/issues/422, 2023-09-22, several users). Reported by several.
- Writing an Int16 buffer into an `AVAudioFile` opened as Float32 traps in CoreAudio (`CABufferList::BytesConsumed`,
  EXC_BREAKPOINT) on iOS 16.x, after a flood of `error -66686` log lines.
  https://github.com/dlutton/flutter_tts/pull/632 (2026-05-10). Single report.
- Sample rate and channel count: no source states them. flutter_tts reads `pcmBuffer.format.sampleRate` and opens the file as
  mono, so rate varies by voice. Log `buffer.format` per voice (flutter_tts prints it). Single report.
- `error -66686` is `kAudioQueueErr_BufferEmpty`; `[AXTTSCommon] ... error -66686 enqueueing buffer` is logged on iOS 16 even
  when `write` gets an empty closure. Feedback filed by the asker, no Apple reply after 8 months.
  https://stackoverflow.com/questions/73716508 (2022-09-14, comment 2023-05-07). Single report.
- End of stream: a final buffer with `frameLength == 0` (some code checks `frameCapacity <= 1`).
  https://github.com/dlutton/flutter_tts (ios plugin, `synthesizeToFile`), https://stackoverflow.com/questions/64022010
  (2020, approx.), https://stackoverflow.com/questions/78657163 (2024-06-22). Reported by several.
- The synthesizer must stay alive until the last buffer: a deallocated one yields an empty stream that never finishes.
  https://stackoverflow.com/questions/78657163 (2024-06-22). Single report.
- `toMarkerCallback` is never invoked on iOS 17 and iOS 18.4, buffers arrive.
  https://stackoverflow.com/questions/78541092 (2024-05-27, comment 2025-05-20). Reported by two users.
- Threading: a Rust binding says delegate events and `write` callbacks arrive on the main thread (120 s timeout without a
  running run loop). https://github.com/doom-fish/avspeechsynthesizer-rs (undated). Single report.
- Simulator: `synthesizeToFile` still failed on iOS 17 simulators after the fix (PR 435, single report). el-GR with `write`
  and leaks: no source found.
- Playing buffers with `AVAudioPlayerNode`: the asker of SO 73716508 converted buffers to Float32 first. No source for the rule
  itself. My inference: the node's connection format must equal the buffer format (or convert with `AVAudioConverter`, see
  Apple TN3136), and voices with different formats need a reconnect or a fixed conversion target.

## 3. Audio session settings

- `usesApplicationAudioSession = false`: system manages activation, interruptions, mixing and ducking; speech ducks and mixes
  with the app's other audio; default true shares the app session. https://developer.apple.com/videos/play/wwdc2020/10022/
  (2020) and the doc page in section 1. Documented.
- `mixToTelephonyUplink` only routes speech into an active call, no effect otherwise.
  https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/mixtotelephonyuplink (doc, 2026). Documented.
- No source found that `.mixWithOthers`, `.duckOthers` or `.spokenAudio` cause glitches. Closest: the 2016 per-speak
  `setCategory`/`setActive` hiccups and the 2026 duckOthers dropped utterance (section 1).

## 4. Voice quality levels

- Greek voices in the iOS 18.5 VoiceOver list: Melina, Nikos (no tier given).
  https://www.applevis.com/guides/deep-dive-voiceover-settings-ios-ipados (2025-05-15). Single report.
- Older lists show only Melina, compact (`com.apple.ttsbundle.Melina-compact`): https://stackoverflow.com/questions/37512621 (2016).
- el-GR names and tiers on iOS 26: no source found. Enumerate on the device.
- Enhanced or premium stuttering on old chips while compact does not: no source found. Only the Siri-voice dropouts on A15/A16
  class phones (section 1) point at neural voices, and flutter_tts #422 says enhanced/premium worked with `write` where default
  voices broke.

## 5. First-syllable cut-off and latency

- `preUtteranceDelay` is a pause before speaking; between queued utterances the minimum pause is the current
  `postUtteranceDelay` plus the next `preUtteranceDelay`.
  https://developer.apple.com/documentation/avfaudio/avspeechutterance/preutterancedelay (doc, 2026). Documented.
- iOS 8: the first utterance in a non-default language was silent or very quiet; workaround was speaking an empty or one-character
  utterance first, Apple's workaround was installing a high-quality voice. https://stackoverflow.com/questions/24197952 (2014),
  https://teamtreehouse.com/community/avspeechsynthesizer-with-swift. Reported by several, old; Mnemit's silent warm-up matches it.
- First-syllable clipping on iOS 17-26: no source found. Session activation timing: only the WWDC18 summary above.

## 6. What others do

- flutter_tts ships `synthesizeToFile` (write into an `AVAudioFile`, CAF), a ready pre-render path, with the format pitfalls from
  section 2. https://github.com/dlutton/flutter_tts (ios plugin, last ios change 2026-01-05).
- Flashcard or language apps: no source found on their practice.

## What this means for Mnemit

- Measure before building: on the iPhone log, per word, the time from `speak` to `didStart` and to `didFinish`, and the time
  `write` needs to deliver its last buffer. Pre-rendering pays only if `write` finishes well ahead of real time.
- Try the cheap switches one at a time behind a flag: `usesApplicationAudioSession = false`; mode `.default` instead of
  `.spokenAudio`; no `.mixWithOthers`. Compare the same word on each. None is proven to help.
- Log every el-GR voice (name, identifier, quality) and the one in use; A/B a compact against an enhanced or premium voice on the
  13 mini. No source separates them for stutter.
- Pre-render to disk, not to live buffers: write each word once (key: voice id + text + rate) into a CAF using the first buffer's
  `format.settings` and `commonFormat`, play it with one stable player. This removes per-voice format handling at play time.
- In the `write` closure guard the cast to `AVAudioPCMBuffer`, treat `frameLength == 0` as the end, never use `try!` on file
  writes, ignore `toMarkerCallback`, keep the synthesizer alive until the end buffer, and keep closure work minimal (callbacks
  may arrive on the main thread).
- If live buffers through `AVAudioEngine` stay the plan: connect the player with the first buffer's format and reconnect (or
  convert to one Float32 mono target) when a later word differs; keep the engine running with a primed silent buffer.
- Test on the device: simulator results for `write` and session behaviour were reported as unreliable.

## Measured and decided (22.10.2026)

- Mac (M-series), `com.apple.voice.compact.el-GR.Melina`: `write` gives Float32 22,050 Hz mono, 66–87 chunks of about
  11 ms per word; the first word 0.78 s (the voice loads), then 13–19 ms per word against 0.76–1.0 s of sound.
- iPhone 13 mini, iOS 26, 4.0.3 (`SpeechLog`): the voice is the same compact Melina (quality 1, no enhanced voice
  installed); the first word 390 ms, then 24–25 ms per word against 0.84–1.18 s of sound; every word played from the
  buffer, 0 ms after it was asked for. EF heard no stutter.
- Shipped: words rendered ahead into one buffer when their card comes up, converted to standard Float32 where a voice
  renders Int16, played through `AVAudioEngine`; live speech only where rendering gives nothing in 3 s. Not needed:
  the session switches above, a disk cache.
