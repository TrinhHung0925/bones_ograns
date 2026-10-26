// Game sound effects synthesised with WebAudio, so no audio files ship.
// The AudioContext is created and resumed on the first touch inside the page
// (mobile WebViews keep audio locked until a user gesture).

const PENTATONIC = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24];

class Sfx {
  constructor() {
    this.enabled = true;
    this.ctx = null;
    this.master = null;
    this.noise = null;
    const unlock = () => {
      this.ensure();
      if (this.ctx?.state === 'suspended') this.ctx.resume().catch(() => {});
      if (this.ctx?.state === 'running') {
        window.removeEventListener('pointerdown', unlock, true);
        window.removeEventListener('touchend', unlock, true);
      }
    };
    window.addEventListener('pointerdown', unlock, true);
    window.addEventListener('touchend', unlock, true);
  }

  ensure() {
    if (this.ctx) return this.ctx;
    const Ctor = window.AudioContext || window.webkitAudioContext;
    if (!Ctor) return null;
    try {
      this.ctx = new Ctor();
    } catch (_) {
      return null;
    }
    const ctx = this.ctx;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14;
    comp.knee.value = 12;
    comp.ratio.value = 4;
    this.master = ctx.createGain();
    this.master.gain.value = 0.55;
    this.master.connect(comp).connect(ctx.destination);
    // One second of white noise, reused by every noisy sound.
    const buf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    this.noise = buf;
    // A silent blip finishes unlocking on iOS.
    const s = ctx.createBufferSource();
    s.buffer = ctx.createBuffer(1, 1, ctx.sampleRate);
    s.connect(ctx.destination);
    s.start();
    return ctx;
  }

  setEnabled(enabled) {
    this.enabled = !!enabled;
    if (this.master && this.ctx) {
      this.master.gain.setTargetAtTime(this.enabled ? 0.55 : 0, this.ctx.currentTime, 0.02);
    }
  }

  /** Context ready to play right now, or null (muted, locked, unsupported). */
  live() {
    if (!this.enabled) return null;
    const ctx = this.ensure();
    if (!ctx || ctx.state !== 'running') return null;
    return ctx;
  }

  tone(ctx, { type = 'sine', freq, to = null, start = 0, dur, gain = 0.3, attack = 0.004, out = this.master, detune = 0 }) {
    const t = ctx.currentTime + start;
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (to) osc.frequency.exponentialRampToValueAtTime(to, t + dur);
    osc.detune.value = detune;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(gain, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(g).connect(out);
    osc.start(t);
    osc.stop(t + dur + 0.05);
    return osc;
  }

  noiseBurst(ctx, { start = 0, dur, gain = 0.2, type = 'bandpass', freq = 2000, to = null, q = 1, attack = 0.003 }) {
    const t = ctx.currentTime + start;
    const src = ctx.createBufferSource();
    src.buffer = this.noise;
    const f = ctx.createBiquadFilter();
    f.type = type;
    f.frequency.setValueAtTime(freq, t);
    if (to) f.frequency.exponentialRampToValueAtTime(to, t + dur);
    f.Q.value = q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(gain, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f).connect(g).connect(this.master);
    src.start(t, Math.random() * 0.5);
    src.stop(t + dur + 0.05);
  }

  /** Soft "pop" when a piece is picked up. */
  grab() {
    const ctx = this.live();
    if (!ctx) return;
    this.tone(ctx, { freq: 520, to: 240, dur: 0.11, gain: 0.32 });
    this.tone(ctx, { freq: 1040, to: 600, dur: 0.05, gain: 0.08, type: 'triangle' });
    this.noiseBurst(ctx, { dur: 0.04, gain: 0.05, freq: 3000, q: 0.8 });
  }

  /** Click + bell chime; [combo] (1, 2, 3...) raises the pitch. */
  snap(combo = 1) {
    const ctx = this.live();
    if (!ctx) return;
    this.noiseBurst(ctx, { dur: 0.035, gain: 0.25, type: 'highpass', freq: 2500, q: 0.7 });
    this.tone(ctx, { freq: 180, to: 90, dur: 0.07, gain: 0.25 });
    const step = PENTATONIC[Math.min(combo - 1, PENTATONIC.length - 1)];
    const f = 784 * Math.pow(2, step / 12);
    this.tone(ctx, { freq: f, start: 0.03, dur: 0.6, gain: 0.2, type: 'sine' });
    this.tone(ctx, { freq: f * 2, start: 0.03, dur: 0.35, gain: 0.07, type: 'sine' });
    this.tone(ctx, { freq: f * 1.5, start: 0.1, dur: 0.5, gain: 0.08, type: 'triangle' });
  }

  /** Low buzz for a piece dropped on the wrong slot. */
  wrong() {
    const ctx = this.live();
    if (!ctx) return;
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 700;
    lp.connect(this.master);
    this.tone(ctx, { type: 'sawtooth', freq: 140, to: 100, dur: 0.26, gain: 0.22, out: lp });
    this.tone(ctx, { type: 'sawtooth', freq: 146, to: 104, dur: 0.26, gain: 0.18, out: lp });
    this.tone(ctx, { type: 'square', freq: 70, dur: 0.2, gain: 0.08, out: lp });
  }

  /** Twinkly sparkle for a hint. */
  hint() {
    const ctx = this.live();
    if (!ctx) return;
    for (let i = 0; i < 6; i++) {
      const step = PENTATONIC[4 + Math.floor(Math.random() * 6)];
      this.tone(ctx, { freq: 1046 * Math.pow(2, step / 12), start: i * 0.055, dur: 0.22, gain: 0.07 + 0.02 * (i % 2), type: i % 2 ? 'triangle' : 'sine' });
    }
    this.noiseBurst(ctx, { dur: 0.35, gain: 0.03, type: 'highpass', freq: 6000, q: 0.5, attack: 0.05 });
  }

  /** Short fanfare when the model is complete. */
  complete() {
    const ctx = this.live();
    if (!ctx) return;
    const notes = [523.25, 659.25, 783.99, 1046.5];
    notes.forEach((f, i) => {
      this.tone(ctx, { type: 'triangle', freq: f, start: i * 0.11, dur: 0.28, gain: 0.2 });
      this.tone(ctx, { type: 'square', freq: f, start: i * 0.11, dur: 0.12, gain: 0.04 });
    });
    for (const f of [523.25, 659.25, 783.99, 1046.5, 1318.5]) {
      this.tone(ctx, { type: 'triangle', freq: f, start: 0.46, dur: 1.1, gain: 0.1, attack: 0.02 });
      this.tone(ctx, { type: 'sine', freq: f, start: 0.46, dur: 1.2, gain: 0.06, attack: 0.02, detune: 7 });
    }
    this.noiseBurst(ctx, { start: 0.44, dur: 0.6, gain: 0.05, type: 'highpass', freq: 5000, attack: 0.01 });
  }

  /** Airy whoosh when pieces scatter. */
  whoosh() {
    const ctx = this.live();
    if (!ctx) return;
    this.noiseBurst(ctx, { dur: 0.7, gain: 0.16, type: 'bandpass', freq: 300, to: 2400, q: 1.4, attack: 0.18 });
    this.noiseBurst(ctx, { start: 0.12, dur: 0.6, gain: 0.08, type: 'bandpass', freq: 600, to: 3600, q: 2, attack: 0.15 });
  }

  /** Faint tick when a dragged piece enters its slot's magnet range. */
  magnet() {
    const ctx = this.live();
    if (!ctx) return;
    this.tone(ctx, { freq: 1568, dur: 0.08, gain: 0.06, type: 'sine' });
  }
}

export const sfx = new Sfx();
