#!/usr/bin/env node
// Prints the eased background of the extension's light-mode iPhone sheet, for
// pasting into extension/popup/popup.css.
//
// A CSS gradient changes linearly between its stops, so wherever its slope
// jumps (at the stops, or the rim of a radial gradient) the eye sees a line
// (Mach bands). These gradients put their stops on a smoothstep curve
// instead, so the color starts and stops changing gently.

const STEPS = 8;
const smoothstep = (t) => t * t * (3 - 2 * t);
const num = (x) => String(Math.round(x * 1000) / 1000);
const steps = () => Array.from({ length: STEPS + 1 }, (_, i) => i / STEPS);

// The title bar's pale lavender (#B4B4DB), fading out over the top `top` px
// and back in over the bottom `bottom` px.
function edge(top, bottom) {
  const edgeColor = (alpha) => `rgb(180 180 219 / ${num(alpha)})`;
  return [
    ...steps().map((t) => `${edgeColor(1 - smoothstep(t))} ${num(t * top)}px`),
    ...steps().map((t) => `${edgeColor(smoothstep(t))} calc(100% - ${num((1 - t) * bottom)}px)`),
  ];
}

// A glow fading out to its rim.
function glow(rgb, alpha) {
  return steps().map((t) => `rgb(${rgb} / ${num(alpha * (1 - smoothstep(t)))}) ${num(t * 100)}%`);
}

const gradient = (kind, args, stops) => `${kind}(${args},\n          ${stops.join(",\n          ")})`;

const layers = [
  gradient("linear-gradient", "to bottom", edge(190, 140)),
  gradient("radial-gradient", "75% 60% at 50% 42%", glow("106 106 184", 0.95)),
  gradient("radial-gradient", "55% 45% at 100% 100%", glow("192 112 184", 0.85)),
  gradient("radial-gradient", "50% 40% at 0% 100%", glow("111 128 194", 0.7)),
  gradient("radial-gradient", "45% 35% at 50% 100%", glow("106 63 152", 0.8)),
  "linear-gradient(to bottom in oklab, #332f7d, #3b2d84)",
];

console.log(`      background:\n        ${layers.join(",\n        ")};`);
