# Voice files

Facts and guide lines are spoken with Godot TTS:

`DisplayServer.tts_speak` in `scripts/autoload/voice.gd`.

Turkish is preferred (`tr`), then any installed voice. The subtitle is always shown, so a missing voice does not hide the fact.

To replace a line with a recording, add an Ogg Vorbis file:

```
res://assets/voice/<clip>_<lang>.ogg
```

`<clip>` is `sounds.voice` in `shared/data/dinosaurs.json` (for example `trex_fact_tr.ogg`). `<lang>` is `tr` or `en`.

If that file exists, the game plays it and does not call TTS for that line.

The web prototype uses `speechSynthesis` the same way. Add the clip id to the `recorded` set in `web/src/audio.js` and put the file in `web/public/voice/`.
