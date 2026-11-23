const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff]);
const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PDF_MAGIC = Buffer.from([0x25, 0x50, 0x44, 0x46]);

const UNREADABLE = 'Unreadable image file.';

const ICC_PREFIX = Buffer.from('ICC_PROFILE\0', 'latin1');
const ADOBE_PREFIX = Buffer.from('Adobe', 'latin1');

// PNG chunks that carry metadata (EXIF, text/XMP, timestamps).
const PNG_DROP = new Set(['eXIf', 'tEXt', 'iTXt', 'zTXt', 'tIME']);

function startsWith(buf, magic) {
  return buf.length >= magic.length && buf.subarray(0, magic.length).equals(magic);
}

function sniffType(buf) {
  if (!Buffer.isBuffer(buf)) return null;
  if (startsWith(buf, JPEG_MAGIC)) return 'image/jpeg';
  if (startsWith(buf, PNG_MAGIC)) return 'image/png';
  if (startsWith(buf, PDF_MAGIC)) return 'application/pdf';
  return null;
}

function isRst(marker) {
  return marker >= 0xd0 && marker <= 0xd7;
}

// Allowlist: APP0 (JFIF), APP2 only for ICC profiles, APP14 only for Adobe colour info.
// Every other APPn (EXIF, XMP, MPF, IPTC, ...) and COM is dropped. Non-APP segments are kept.
function keepJpegSegment(marker, payload) {
  if (marker === 0xfe) return false;
  if (marker < 0xe0 || marker > 0xef) return true;
  if (marker === 0xe0) return true;
  if (marker === 0xe2) return startsWith(payload, ICC_PREFIX);
  if (marker === 0xee) return startsWith(payload, ADOBE_PREFIX);
  return false;
}

// Scans entropy-coded data from `start` for the next real marker, skipping stuffed
// bytes (FF 00), restart markers (FF D0-D7) and FF fill. Returns the offset of the
// first FF of that marker run and the marker byte.
function findNextMarker(buf, start) {
  let i = start;
  for (;;) {
    const ff = buf.indexOf(0xff, i);
    if (ff === -1) throw new Error(UNREADABLE);
    let k = ff + 1;
    while (k < buf.length && buf[k] === 0xff) k += 1;
    if (k >= buf.length) throw new Error(UNREADABLE);
    const marker = buf[k];
    if (marker === 0x00 || isRst(marker)) {
      i = k + 1;
      continue;
    }
    return { at: ff, marker };
  }
}

// Walks the JPEG from SOI to the first EOI, dropping metadata segments, including any
// between progressive scans. Everything after EOI (MPF secondary images, gain maps,
// trailers) is discarded. Image data is copied byte for byte, never re-encoded.
function stripJpeg(buf) {
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) throw new Error(UNREADABLE);
  const parts = [buf.subarray(0, 2)];
  let pos = 2;
  for (;;) {
    if (pos >= buf.length || buf[pos] !== 0xff) throw new Error(UNREADABLE);
    let markerPos = pos;
    while (markerPos < buf.length && buf[markerPos] === 0xff) markerPos += 1;
    if (markerPos >= buf.length) throw new Error(UNREADABLE);
    const marker = buf[markerPos];

    if (marker === 0xd9) {
      parts.push(Buffer.from([0xff, 0xd9]));
      return Buffer.concat(parts);
    }
    if (marker === 0x00 || marker === 0xd8) throw new Error(UNREADABLE);
    if (marker === 0x01 || isRst(marker)) {
      parts.push(Buffer.from([0xff, marker]));
      pos = markerPos + 1;
      continue;
    }

    if (markerPos + 3 > buf.length) throw new Error(UNREADABLE);
    const length = buf.readUInt16BE(markerPos + 1);
    const end = markerPos + 1 + length;
    if (length < 2 || end > buf.length) throw new Error(UNREADABLE);

    if (keepJpegSegment(marker, buf.subarray(markerPos + 3, end))) {
      parts.push(buf.subarray(markerPos - 1, end));
    }
    pos = end;

    if (marker === 0xda) {
      const next = findNextMarker(buf, end);
      parts.push(buf.subarray(end, next.at));
      pos = next.at;
    }
  }
}

// Drops metadata chunks. Each chunk is length(4) + type(4) + data + CRC(4).
function stripPng(buf) {
  if (!startsWith(buf, PNG_MAGIC)) throw new Error(UNREADABLE);
  const parts = [buf.subarray(0, PNG_MAGIC.length)];
  let pos = PNG_MAGIC.length;
  let sawEnd = false;
  while (pos < buf.length) {
    if (pos + 12 > buf.length) throw new Error(UNREADABLE);
    const length = buf.readUInt32BE(pos);
    const end = pos + 12 + length;
    if (end > buf.length) throw new Error(UNREADABLE);
    const type = buf.toString('latin1', pos + 4, pos + 8);
    if (!PNG_DROP.has(type)) parts.push(buf.subarray(pos, end));
    pos = end;
    if (type === 'IEND') {
      sawEnd = true;
      break;
    }
  }
  if (!sawEnd) throw new Error(UNREADABLE);
  return Buffer.concat(parts);
}

function stripMetadata(buf, type) {
  if (type === 'image/jpeg') return stripJpeg(buf);
  if (type === 'image/png') return stripPng(buf);
  return buf;
}

module.exports = { sniffType, stripMetadata };
