/**
 * Generates a 1024×1024 DropIt app icon as a PNG.
 * Design: diagonal #6C63FF→#3B82F6 gradient background,
 * white download arrow (shaft + chevron head + bottom bar), pure Node.js / zlib only.
 */
'use strict';
const zlib = require('zlib');
const fs   = require('fs');
const path = require('path');

const SIZE = 1024;

// ── helpers ────────────────────────────────────────────────────────────────

function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
function mix(a, b, t)     { return a + (b - a) * t; }
function smoothstep(lo, hi, x) {
  const t = clamp((x - lo) / (hi - lo), 0, 1);
  return t * t * (3 - 2 * t);
}
function hypot(dx, dy) { return Math.sqrt(dx * dx + dy * dy); }

// Signed distance to an axis-aligned rounded rectangle (centred at ox,oy)
function sdfRRect(px, py, ox, oy, hw, hh, r) {
  const qx = Math.abs(px - ox) - hw + r;
  const qy = Math.abs(py - oy) - hh + r;
  return Math.min(Math.max(qx, qy), 0) + hypot(Math.max(qx, 0), Math.max(qy, 0)) - r;
}

// Signed distance to a filled triangle (p1,p2,p3 wound counter-clockwise)
function sdfTriangle(px, py, x1, y1, x2, y2, x3, y3) {
  function edgeDist(ax, ay, bx, by) {
    const ex = bx - ax, ey = by - ay;
    const wx = px - ax, wy = py - ay;
    const t = clamp((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1);
    return hypot(wx - t * ex, wy - t * ey);
  }
  function sign2d(ax, ay, bx, by, cx, cy) {
    return (ax - cx) * (by - cy) - (bx - cx) * (ay - cy);
  }
  const d1 = sign2d(px, py, x1, y1, x2, y2);
  const d2 = sign2d(px, py, x2, y2, x3, y3);
  const d3 = sign2d(px, py, x3, y3, x1, y1);
  const inside = (d1 <= 0 && d2 <= 0 && d3 <= 0) ||
                 (d1 >= 0 && d2 >= 0 && d3 >= 0);
  const edge = Math.min(edgeDist(x1, y1, x2, y2),
                        edgeDist(x2, y2, x3, y3),
                        edgeDist(x3, y3, x1, y1));
  return inside ? -edge : edge;
}

// ── render ─────────────────────────────────────────────────────────────────

const AA  = 1.8;        // anti-alias half-width in pixels
const cx  = SIZE / 2;
const cy  = SIZE / 2;
const S   = SIZE * 0.5; // icon scale unit (half of canvas)

// Icon geometry (all values relative to S, centred at cx,cy):
//   • Top bar   : horizontal rounded rect at top
//   • Shaft     : narrow vertical rounded rect
//   • Arrowhead : downward-pointing triangle below shaft
//   • Base bar  : horizontal rounded rect at very bottom

// Top bar
const BAR_TOP_HW = S * 0.22,  BAR_TOP_HH = S * 0.055, BAR_TOP_R = S * 0.04;
const BAR_TOP_OY = cy - S * 0.41;

// Shaft
const SHAFT_HW = S * 0.075, SHAFT_HH = S * 0.23, SHAFT_R = S * 0.05;
const SHAFT_OY = cy - S * 0.12;

// Arrowhead triangle — tip points down
const HEAD_TOP_Y = cy + S * 0.12;
const HEAD_TIP_Y = cy + S * 0.40;
const HEAD_HALF_W = S * 0.225;

// Base bar
const BAR_BOT_HW = S * 0.22,  BAR_BOT_HH = S * 0.055, BAR_BOT_R = S * 0.04;
const BAR_BOT_OY = cy + S * 0.53;

// Build raw scanlines (PNG filter byte 0 = None, then RGBA per pixel)
const scanlines = [];
for (let y = 0; y < SIZE; y++) {
  const row = Buffer.alloc(1 + SIZE * 4);
  row[0] = 0; // filter None

  for (let x = 0; x < SIZE; x++) {
    // ── gradient background ──────────────────────────────────────────────
    const t  = (x + y) / (2 * (SIZE - 1));
    const bgR = mix(0x6C, 0x3B, t);
    const bgG = mix(0x63, 0x82, t);
    const bgB = mix(0xFF, 0xF6, t);

    // ── icon SDF union ───────────────────────────────────────────────────
    const dTopBar  = sdfRRect(x, y, cx, BAR_TOP_OY, BAR_TOP_HW, BAR_TOP_HH, BAR_TOP_R);
    const dShaft   = sdfRRect(x, y, cx, SHAFT_OY,   SHAFT_HW,   SHAFT_HH,   SHAFT_R);
    const dHead    = sdfTriangle(
      x, y,
      cx - HEAD_HALF_W, HEAD_TOP_Y,  // left
      cx + HEAD_HALF_W, HEAD_TOP_Y,  // right
      cx,               HEAD_TIP_Y   // tip (down)
    );
    const dBotBar  = sdfRRect(x, y, cx, BAR_BOT_OY, BAR_BOT_HW, BAR_BOT_HH, BAR_BOT_R);

    const d = Math.min(dTopBar, dShaft, dHead, dBotBar);

    // ── blend white icon over gradient ───────────────────────────────────
    const alpha = smoothstep(AA, -AA, d);

    const off = 1 + x * 4;
    row[off]     = Math.round(mix(bgR, 255, alpha));
    row[off + 1] = Math.round(mix(bgG, 255, alpha));
    row[off + 2] = Math.round(mix(bgB, 255, alpha));
    row[off + 3] = 255;
  }
  scanlines.push(row);
}

// ── PNG encoding ────────────────────────────────────────────────────────────

function u32be(n) {
  const b = Buffer.alloc(4);
  b.writeUInt32BE(n, 0);
  return b;
}
function chunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii');
  const len = u32be(data.length);
  const crcInput = Buffer.concat([typeBytes, data]);
  const crc = u32be(crc32(crcInput));
  return Buffer.concat([len, typeBytes, data, crc]);
}

// CRC-32 table
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (const byte of buf) c = CRC_TABLE[(c ^ byte) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

const IHDR = Buffer.alloc(13);
IHDR.writeUInt32BE(SIZE, 0);   // width
IHDR.writeUInt32BE(SIZE, 4);   // height
IHDR[8]  = 8;  // bit depth
IHDR[9]  = 6;  // colour type: RGBA
IHDR[10] = 0;  // compression
IHDR[11] = 0;  // filter
IHDR[12] = 0;  // interlace

const rawPixels = Buffer.concat(scanlines);
const compressed = zlib.deflateSync(rawPixels, { level: 9 });

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),  // signature
  chunk('IHDR', IHDR),
  chunk('IDAT', compressed),
  chunk('IEND', Buffer.alloc(0)),
]);

const outPath = path.join(__dirname, '..', 'assets', 'icon.png');
fs.writeFileSync(outPath, png);
console.log(`✓ Icon written to ${outPath} (${(png.length / 1024).toFixed(1)} KB)`);
