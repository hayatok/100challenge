// Tiny synthesized feedback, unlocked only by an explicit user gesture. No network assets.
let context: AudioContext | undefined;
export function unlockSound() {
  try {
    context ??= new AudioContext();
    void context.resume().catch(() => {});
  } catch {
    /* Silent play remains available. */
  }
}
export function playSound(kind: "catch" | "stop" | "fall" | "miss") {
  if (!context || context.state !== "running") return;
  try {
    const time = context.currentTime;
    const oscillator = context.createOscillator(),
      gain = context.createGain();
    oscillator.type = "sine";
    const frequencies = {
      catch: [380, 620],
      stop: [440, 880],
      fall: [240, 65],
      miss: [170, 130],
    }[kind];
    oscillator.frequency.setValueAtTime(frequencies[0], time);
    oscillator.frequency.exponentialRampToValueAtTime(
      frequencies[1],
      time + 0.14,
    );
    gain.gain.setValueAtTime(0, time);
    gain.gain.linearRampToValueAtTime(0.09, time + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.001, time + 0.25);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(time);
    oscillator.stop(time + 0.26);
    oscillator.onended = () => {
      oscillator.disconnect();
      gain.disconnect();
    };
  } catch {
    /* Audio device errors never block the game. */
  }
}
