import { brakingDistance, type Game } from "./simulation";
/** Deterministic input policies for regression tests and DEV-only visual playback. */
export function recordedInput(g: Game, mode: string): boolean {
  const distance = g.route[g.leg].length - g.x;
  if (mode === "hold") return true;
  if (mode === "idle") return false;
  if (mode === "late") return distance > 5;
  if (mode === "safe")
    return (
      g.speed <
      Math.min(10, Math.sqrt(Math.max(0, 2 * 10 * (distance - 0.4))) * 0.85)
    );
  if (mode === "brake")
    return !g.braking && distance > brakingDistance(g.speed);
  // Lift early enough to reserve ~1.5m for the brief recovery pulse.
  const margin = mode === "early" ? 4 : 1.5;
  return (
    (!g.braking && distance > brakingDistance(g.speed) + margin) ||
    (g.lean > 0.84 && g.angular > -0.1)
  );
}
