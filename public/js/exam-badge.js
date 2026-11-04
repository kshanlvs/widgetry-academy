// Exam Center badges: the SVG shown on the site and a PNG share card drawn on a canvas.
// Used by exam.html and badge.html.

export const LEVEL_LOOK = {
  junior: { name: "Junior", ring: ["#6fe0bd", "#0f6b56"], accent: "#3fc79f", chevrons: 1, tag: "0–2 YEARS" },
  mid:    { name: "Mid level", ring: ["#ffd166", "#c98a00"], accent: "#f5b82e", chevrons: 2, tag: "2–5 YEARS" },
  senior: { name: "Senior", ring: ["#ffe29a", "#f2a900"], accent: "#ffd166", chevrons: 3, tag: "5+ YEARS" },
};

const HEX = "M120 8 L222 66 L222 186 L120 244 L18 186 L18 66 Z";
const HEX_IN = "M120 26 L206 75 L206 177 L120 226 L34 177 L34 75 Z";
let uid = 0;

/** The badge as SVG markup. opts: { score, distinction, locked, size } */
export function badgeSVG(level, opts = {}) {
  const L = LEVEL_LOOK[level] || LEVEL_LOOK.junior;
  const id = "bg" + (++uid);
  const size = opts.size || 200;
  const chev = Array.from({ length: L.chevrons }, (_, i) =>
    `<path d="M96 ${170 + i * 11} L120 ${182 + i * 11} L144 ${170 + i * 11}" fill="none" stroke="${L.accent}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>`).join("");
  const word = L.name.toUpperCase();
  const fs = word.length > 7 ? 21 : 27;
  return `<svg class="badge-svg${opts.locked ? " locked" : ""}" viewBox="0 0 240 270" width="${size}" height="${Math.round(size * 270 / 240)}" role="img" aria-label="Widgetry Flutter ${L.name} badge${opts.locked ? " (locked)" : ""}">
  <defs>
    <linearGradient id="${id}r" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${L.ring[0]}"/><stop offset="1" stop-color="${L.ring[1]}"/></linearGradient>
    <radialGradient id="${id}i" cx="50%" cy="35%" r="75%"><stop offset="0" stop-color="#174a3d"/><stop offset="1" stop-color="#071a15"/></radialGradient>
    <linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient>
  </defs>
  <path d="${HEX}" fill="url(#${id}r)"/>
  <path d="${HEX_IN}" fill="url(#${id}i)"/>
  <path d="${HEX_IN}" fill="url(#${id}s)"/>
  <g transform="translate(103 44)">
    <rect width="15" height="15" rx="3.5" fill="#f2a900"/><rect x="19" width="15" height="15" rx="3.5" fill="#3fc79f"/>
    <rect y="19" width="15" height="15" rx="3.5" fill="#3fc79f"/><rect x="19" y="19" width="15" height="15" rx="3.5" fill="#fff"/>
  </g>
  <text x="120" y="108" text-anchor="middle" font-family="JetBrains Mono, monospace" font-size="11" font-weight="700" letter-spacing="3" fill="${L.accent}">FLUTTER</text>
  <text x="120" y="142" text-anchor="middle" font-family="Unbounded, sans-serif" font-size="${fs}" font-weight="800" fill="#fff">${word}</text>
  <text x="120" y="160" text-anchor="middle" font-family="DM Sans, sans-serif" font-size="10.5" font-weight="700" letter-spacing="1.5" fill="#a8c2b6">${opts.score != null ? `${opts.score}% ${opts.distinction ? "· DISTINCTION" : "· VERIFIED"}` : L.tag}</text>
  ${chev}
  <g transform="translate(0 232)">
    <rect x="44" y="0" width="152" height="26" rx="13" fill="#0c2a23" stroke="url(#${id}r)" stroke-width="2"/>
    <text x="120" y="17.5" text-anchor="middle" font-family="DM Sans, sans-serif" font-size="10" font-weight="800" letter-spacing="1.6" fill="#eaf3ee">WIDGETRY ACADEMY</text>
  </g>
  ${opts.locked ? `<g transform="translate(184 196)"><circle r="24" fill="#0c2a23" stroke="#eaf3ee" stroke-opacity=".6" stroke-width="2"/><rect x="-10" y="-3" width="20" height="15" rx="3" fill="#eaf3ee"/><path d="M-6 -3 v-5 a6 6 0 0 1 12 0 v5" fill="none" stroke="#eaf3ee" stroke-width="3"/></g>` : ""}
</svg>`;
}

function hexPath(ctx, cx, cy, r) {
  ctx.beginPath();
  for (let i = 0; i < 6; i++) { const a = Math.PI / 6 + i * Math.PI / 3; const x = cx + r * Math.cos(a - Math.PI / 2 + Math.PI / 2), y = cy + r * Math.sin(a - Math.PI / 2 + Math.PI / 2); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
  ctx.closePath();
}

/** A 1200 × 630 PNG to post on LinkedIn or WhatsApp. Returns a Blob. */
export async function shareCard(badge) {
  const L = LEVEL_LOOK[badge.level] || LEVEL_LOOK.junior;
  try { await Promise.all(["800 60px Unbounded", "700 30px 'DM Sans'", "500 24px 'DM Sans'", "700 20px 'JetBrains Mono'"].map(f => document.fonts.load(f))); } catch {}
  const c = document.createElement("canvas"); c.width = 1200; c.height = 630;
  const x = c.getContext("2d");
  const bg = x.createLinearGradient(0, 0, 1200, 630); bg.addColorStop(0, "#0c2a23"); bg.addColorStop(1, "#061411");
  x.fillStyle = bg; x.fillRect(0, 0, 1200, 630);
  // soft glow behind the badge
  const glow = x.createRadialGradient(300, 315, 20, 300, 315, 300); glow.addColorStop(0, L.accent + "55"); glow.addColorStop(1, "#0c2a2300");
  x.fillStyle = glow; x.fillRect(0, 0, 640, 630);
  // badge
  const ring = x.createLinearGradient(160, 120, 440, 520); ring.addColorStop(0, L.ring[0]); ring.addColorStop(1, L.ring[1]);
  hexPath(x, 300, 315, 210); x.fillStyle = ring; x.fill();
  hexPath(x, 300, 315, 178); x.fillStyle = "#0b2621"; x.fill();
  x.textAlign = "center";
  x.fillStyle = L.accent; x.font = "700 20px 'JetBrains Mono', monospace"; x.fillText("F L U T T E R", 300, 250);
  x.fillStyle = "#fff"; x.font = `800 ${L.name.length > 7 ? 44 : 56}px Unbounded, sans-serif`; x.fillText(L.name.toUpperCase(), 300, 322);
  x.fillStyle = "#a8c2b6"; x.font = "700 22px 'DM Sans', sans-serif"; x.fillText(`${badge.score}% ${badge.distinction ? "· DISTINCTION" : "· VERIFIED"}`, 300, 362);
  x.strokeStyle = L.accent; x.lineWidth = 9; x.lineCap = "round"; x.lineJoin = "round";
  for (let i = 0; i < L.chevrons; i++) { x.beginPath(); x.moveTo(256, 392 + i * 20); x.lineTo(300, 414 + i * 20); x.lineTo(344, 392 + i * 20); x.stroke(); }
  // text side
  x.textAlign = "left";
  x.fillStyle = "#3fc79f"; x.font = "700 22px 'JetBrains Mono', monospace"; x.fillText("WIDGETRY ACADEMY · EXAM CENTER", 600, 170);
  x.fillStyle = "#fff"; x.font = "800 50px Unbounded, sans-serif";
  const name = badge.name.length > 22 ? badge.name.slice(0, 21) + "…" : badge.name;
  x.fillText(name, 600, 250);
  x.fillStyle = "#cfe3da"; x.font = "500 30px 'DM Sans', sans-serif";
  x.fillText(`earned the Flutter ${L.name} badge`, 600, 300);
  x.fillStyle = L.accent; x.font = "700 30px 'DM Sans', sans-serif";
  x.fillText(`${badge.correct}/${badge.total} correct · ${badge.score}%`, 600, 360);
  x.fillStyle = "#a8c2b6"; x.font = "500 24px 'DM Sans', sans-serif";
  x.fillText(new Date(badge.issuedAt).toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric" }), 600, 400);
  x.fillStyle = "#eaf3ee"; x.font = "500 22px 'DM Sans', sans-serif";
  x.fillText(`Verify: widgetryacademy.in/badge.html?id=${badge.id}`, 600, 520);
  return await new Promise(r => c.toBlob(r, "image/png"));
}

export const badgeUrl = id => `https://widgetryacademy.in/badge.html?id=${encodeURIComponent(id)}`;

/** LinkedIn's "Add licence or certification" form, pre-filled. */
export function linkedInAdd(badge) {
  const d = new Date(badge.issuedAt);
  const p = new URLSearchParams({
    startTask: "CERTIFICATION_NAME", name: `Flutter ${LEVEL_LOOK[badge.level]?.name || ""} Developer Badge`.replace(/\s+/g, " "),
    organizationName: "Widgetry Academy", issueYear: String(d.getFullYear()), issueMonth: String(d.getMonth() + 1),
    certUrl: badgeUrl(badge.id), certId: badge.id,
  });
  return "https://www.linkedin.com/profile/add?" + p.toString();
}
