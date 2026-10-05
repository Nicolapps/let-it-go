// The toolbar button's popover: the app's "Redirect go/ to" field on its
// snowy background. Saving goes through the native handler, which writes the
// same App Group setting the app does.

const DEFAULT_BASE = "http://go";

const input = document.getElementById("redirect-base");
const field = input.parentElement;
const feedback = document.getElementById("feedback");

let value = DEFAULT_BASE;
let feedbackTimer;

// Return, Tab or clicking away saves; Escape puts the old value back. A save
// is confirmed with a checkmark; an invalid value shakes the field and shows a
// red cross until it's edited.
async function commit() {
  const trimmed = input.value.trim();
  if (trimmed === value) {
    input.value = value;
    return;
  }
  if (!isValid(trimmed)) {
    showFeedback("invalid");
    field.classList.remove("shake");
    void field.offsetWidth; // Restarts the animation.
    field.classList.add("shake");
    return;
  }
  value = trimmed;
  input.value = trimmed;
  input.blur();
  await browser.runtime.sendNativeMessage("application.id", { type: "setRedirectBase", redirectBase: trimmed });
  // Points the rules at the new target.
  await browser.runtime.sendMessage({ type: "redirectBase" });
  showFeedback("saved");
}

function showFeedback(kind) {
  clearTimeout(feedbackTimer);
  feedback.className = kind;
  feedback.textContent = kind === "saved" ? "✓" : "✕";
  if (kind === "saved") feedbackTimer = setTimeout(() => (feedback.className = ""), 1500);
}

// Accepts what background.js's normalizeBase can turn into a redirect: a bare
// host like `go` or `go.example.com`, or an http(s) URL, with no query or
// fragment.
function isValid(base) {
  if (!base || /\s/.test(base)) return false;
  try {
    const url = new URL(base.includes("://") ? base : "http://" + base);
    return ["http:", "https:"].includes(url.protocol) && url.hostname !== "" && !url.search && !url.hash;
  } catch {
    return false;
  }
}

input.addEventListener("input", () => {
  if (feedback.className === "invalid" || input.value !== value) feedback.className = "";
});
input.addEventListener("keydown", (event) => {
  if (event.key === "Enter" || event.key === "Tab") {
    event.preventDefault();
    commit();
  } else if (event.key === "Escape") {
    event.preventDefault();
    input.value = value;
    input.blur();
  }
});
input.addEventListener("blur", commit);

browser.runtime.sendNativeMessage("application.id", { type: "redirectBase" }).then((response) => {
  value = response?.redirectBase || DEFAULT_BASE;
  if (document.activeElement !== input) input.value = value;
});
input.value = value;

// MARK: - Snowfall

// A few slow, soft flakes drifting down behind the content.
const canvas = document.getElementById("snow");
const context = canvas.getContext("2d");
const flakes = Array.from({ length: 30 }, () => ({
  x: Math.random(),
  phase: Math.random(),
  speed: 0.02 + Math.random() * 0.04,
  size: 1.5 + Math.random() * 2.5,
  opacity: 0.15 + Math.random() * 0.4,
  sway: 4 + Math.random() * 10,
}));
const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)");

function drawSnow(time) {
  const scale = devicePixelRatio;
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  if (canvas.width !== width * scale || canvas.height !== height * scale) {
    canvas.width = width * scale;
    canvas.height = height * scale;
  }
  context.setTransform(scale, 0, 0, scale, 0, 0);
  context.clearRect(0, 0, width, height);

  const t = time / 1000;
  for (const flake of flakes) {
    const progress = (flake.phase + t * flake.speed) % 1;
    const y = progress * (height + 20) - 10;
    const x = flake.x * width + Math.sin(t * 0.6 + flake.phase * 10) * flake.sway;
    context.beginPath();
    context.arc(x + flake.size / 2, y + flake.size / 2, flake.size / 2, 0, Math.PI * 2);
    context.fillStyle = `rgb(255 255 255 / ${flake.opacity})`;
    context.fill();
  }
  if (!reduceMotion.matches) requestAnimationFrame(drawSnow);
}

requestAnimationFrame(drawSnow);
reduceMotion.addEventListener("change", () => requestAnimationFrame(drawSnow));
