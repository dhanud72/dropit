/**
 * Generates a 1024×1024 transparent-background foreground layer for
 * Android adaptive icons. The white download arrow is centred and scaled
 * to ~66% of the canvas so it sits well within Android's safe-zone circle.
 */
'use strict';
const zlib = require('zlib');
const fs   = require('fs');
const path = require('path');

const SIZE = 1024;
const cx   = SIZE / 2;
const cy   = SIZE / 2;
// Foreground arrow is smaller than the full icon — fits inside the 66% safe zone
const S    = SIZE * 0.30;

function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
function mix(a, b, t)     { return a + (b - a) * t; }
function smoothstep(lo, hi, x) {
  const t = clamp((x - lo) / (hi - lo), 0, 1);
  return t * t * (3 - 2 * t);
}
function hypot(dx, dy) { return Math.sqrt(dx * dx + dy * dy); }

function sdfRRect(px, py, ox, oy, hw, hh, r) {
  const qx = Math.abs(px - ox) - hw + r;
  const qy = Math.abs(py - oy) - hh + r;
  return Math.min(Math.max(qx, qy), 0) + hypot(Math.max(qx, 0), Math.max(qy, 0)) - r;
}

function sdfTriangle(px, py, x1, y1, x2, y2, x3, y3) {
  function edgeDist(ax, ay, bx, by) {
    const ex = bx - ax, ey = by - ay;
    const wx = px - ax, wy = py - ay;
    const t = clamp((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1);
    return hypot(wx - t * ex, wy - t * ey);
  }
  function sign2d(ax, ay, bx, by, cx2, cy2) {
    return (ax - cx2) * (by - cy2) - (bx - cx2) * (ay - cy2);
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

const AA = 1.8;

const BAR_TOP_OY = cy - S * 0.41;
const SHAFT_OY   = cy - S * 0.12;
const HEAD_TOP_Y = cy + S * 0.12;
const HEAD_TIP_Y = cy + S * 0.40;
const HEAD_HW    = S * 0.225;
const BAR_BOT_OY = cy + S * 0.53;

const scanlines = [];
for (let y = 0; y < SIZE; y++) {
  const row = Buffer.alloc(1 + SIZE * 4);
  row[0] = 0;

  for (let x = 0; x < SIZE; x++) {
    const dTopBar = sdfRRect(x, y, cx, BAR_TOP_OY, S * 0.22, S * 0.055, S * 0.04);
    const dShaft  = sdfRRect(x, y, cx, SHAFT_OY,   S * 0.075, S * 0.23, S * 0.05);
    const dHead   = sdfTriangle(x, y,
      cx - HEAD_HW, HEAD_TOP_Y,
      cx + HEAD_HW, HEAD_TOP_Y,
      cx,           HEAD_TIP_Y);
    const dBotBar = sdfRRect(x, y, cx, BAR_BOT_OY, S * 0.22, S * 0.055, S * 0.04);

    const d     = Math.min(dTopBar, dShaft, dHead, dBotBar);
    const alpha = smoothstep(AA, -AA, d);

    const off = 1 + x * 4;
    row[off]     = 255;
    row[off + 1] = 255;
    row[off + 2] = 255;
    row[off + 3] = Math.round(alpha * 255);
  }
  scanlines.push(row);
}

// ── PNG encoding (RGBA) ─────────────────────────────────────────────────────
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
function u32be(n) { const b = Buffer.alloc(4); b.writeUInt32BE(n, 0); return b; }
function chunk(type, data) {
  const tb = Buffer.from(type, 'ascii');
  return Buffer.concat([u32be(data.length), tb, data,
                        u32be(crc32(Buffer.concat([tb, data])))]);
}

const IHDR = Buffer.alloc(13);
IHDR.writeUInt32BE(SIZE, 0);
IHDR.writeUInt32BE(SIZE, 4);
IHDR[8] = 8; IHDR[9] = 6; // RGBA

const compressed = zlib.deflateSync(Buffer.concat(scanlines), { level: 9 });
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
  chunk('IHDR', IHDR),
  chunk('IDAT', compressed),
  chunk('IEND', Buffer.alloc(0)),
]);

const outPath = path.join(__dirname, '..', 'assets', 'icon_foreground.png');
fs.writeFileSync(outPath, png);
console.log(`✓ Foreground written to ${outPath} (${(png.length / 1024).toFixed(1)} KB)`);
