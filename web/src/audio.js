export function createAudio() {
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  let ctx = null;
  let music = null;
  let settings = { music: 0.55, sfx: 0.85, voice: 1 };

  function context() {
    if (!ctx) ctx = new AudioCtx();
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
  }

  function tone(freq, dur, type = "sine", gain = 0.2) {
    if (settings.sfx <= 0.01) return;
    const audio = context();
    const osc = audio.createOscillator();
    const amp = audio.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    amp.gain.setValueAtTime(gain * settings.sfx, audio.currentTime);
    amp.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + dur);
    osc.connect(amp);
    amp.connect(audio.destination);
    osc.start();
    osc.stop(audio.currentTime + dur);
  }

  function noise(dur, gain = 0.15) {
    if (settings.sfx <= 0.01) return;
    const audio = context();
    const length = Math.floor(audio.sampleRate * dur);
    const buffer = audio.createBuffer(1, length, audio.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < length; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / length);
    const src = audio.createBufferSource();
    src.buffer = buffer;
    const amp = audio.createGain();
    amp.gain.value = gain * settings.sfx;
    src.connect(amp);
    amp.connect(audio.destination);
    src.start();
  }

  function play(name) {
    if (name === "dig") noise(0.16, 0.22);
    else if (name === "brush") noise(0.12, 0.08);
    else if (name === "spray") tone(880, 0.16, "sine", 0.08);
    else if (name === "pick") tone(140, 0.1, "square", 0.12);
    else if (name === "chisel") tone(320, 0.08, "square", 0.1);
    else if (name === "wrong") tone(180, 0.16, "sine", 0.12);
    else if (name === "crack") noise(0.2, 0.25);
    else if (name === "collect") {
      tone(523, 0.12);
      setTimeout(() => tone(659, 0.12), 90);
      setTimeout(() => tone(784, 0.16), 180);
    } else if (name === "snap") tone(740, 0.08);
    else if (name === "ui") tone(520, 0.07, "sine", 0.1);
    else if (name === "ping") {
      tone(660, 0.1);
      setTimeout(() => tone(880, 0.12), 80);
    } else if (name === "star") {
      [523, 659, 784, 1046].forEach((freq, i) => setTimeout(() => tone(freq, 0.12), i * 90));
    } else if (name.startsWith("roar")) {
      const base = name.endsWith("high") ? 280 : name.endsWith("low") ? 90 : 150;
      tone(base, 0.45, "sawtooth", 0.12);
      noise(0.4, 0.08);
    }
  }

  function startMusic() {
    const audio = context();
    if (music) return;
    const notes = [262, 330, 392, 494];
    const osc = audio.createOscillator();
    const amp = audio.createGain();
    osc.type = "sine";
    amp.gain.value = 0.03 * settings.music;
    osc.connect(amp);
    amp.connect(audio.destination);
    let step = 0;
    osc.frequency.value = notes[0];
    const timer = setInterval(() => {
      step = (step + 1) % notes.length;
      if (ctx) osc.frequency.setTargetAtTime(notes[step], ctx.currentTime, 0.05);
      amp.gain.value = settings.music <= 0.01 ? 0 : 0.03 * settings.music;
    }, 700);
    osc.start();
    music = { osc, amp, timer };
  }

  function apply(next) {
    settings = { ...settings, ...next };
    if (music) music.amp.gain.value = settings.music <= 0.01 ? 0 : 0.03 * settings.music;
  }

  // Drop a clip at public/voice/<clipId>_<lang>.ogg and add its id here
  // to replace speech synthesis for that line.
  const recorded = new Set();

  function speak(text, lang, clipId) {
    if (settings.voice <= 0.01 || !text) return;
    if (clipId && recorded.has(`${clipId}_${lang}`)) {
      const audio = new Audio(`/voice/${clipId}_${lang}.ogg`);
      audio.volume = settings.voice;
      audio.play().catch(() => speakTts(text, lang));
      return;
    }
    speakTts(text, lang);
  }

  function speakTts(text, lang) {
    if (!window.speechSynthesis) return;
    const utter = new SpeechSynthesisUtterance(text);
    utter.lang = lang === "tr" ? "tr-TR" : "en-US";
    utter.volume = settings.voice;
    utter.rate = 0.95;
    const voices = speechSynthesis.getVoices();
    const match = voices.find((voice) => voice.lang.toLowerCase().startsWith(lang));
    if (match) utter.voice = match;
    speechSynthesis.cancel();
    speechSynthesis.speak(utter);
  }

  function unlock() {
    context();
    startMusic();
  }

  return { play, apply, speak, unlock };
}
