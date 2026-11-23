const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff]);
const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PDF_MAGIC = Buffer.from([0x25, 0x50, 0x44, 0x46]);

const UNREADABLE = 'Unreadable image file.';

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

// Markers with no length field: TEM (0x01) and RST0-RST7 (0xD0-0xD7).
function isStandalone(marker) {
  return marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7);
}

// Drops every APP1 (EXIF/XMP) segment. Walks header segments from SOI until SOS,
// then copies the entropy-coded data and trailer verbatim. Never re-encodes.
function stripJpeg(buf) {
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) throw new Error(UNREADABLE);
  const parts = [buf.subarray(0, 2)];
  let pos = 2;
  for (;;) {
    if (pos >= buf.length || buf[pos] !== 0xff) throw new Error(UNREADABLE);
    // Any number of 0xFF fill bytes may precede a marker.
    let markerPos = pos;
    while (markerPos < buf.length && buf[markerPos] === 0xff) markerPos += 1;
    if (markerPos >= buf.length) throw new Error(UNREADABLE);
    const marker = buf[markerPos];
    if (marker === 0x00) throw new Error(UNREADABLE);

    if (marker === 0xd9) {
      parts.push(buf.subarray(pos));
      break;
    }
    if (isStandalone(marker)) {
      parts.push(buf.subarray(pos, markerPos + 1));
      pos = markerPos + 1;
      continue;
    }
    if (markerPos + 3 > buf.length) throw new Error(UNREADABLE);
    const length = buf.readUInt16BE(markerPos + 1);
    const end = markerPos + 1 + length;
    if (length < 2 || end > buf.length) throw new Error(UNREADABLE);

    if (marker === 0xda) {
      parts.push(buf.subarray(pos));
      break;
    }
    if (marker !== 0xe1) parts.push(buf.subarray(pos, end));
    pos = end;
  }
  return Buffer.concat(parts);
}

// Drops every eXIf chunk. Each chunk is length(4) + type(4) + data + CRC(4).
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
    if (type !== 'eXIf') parts.push(buf.subarray(pos, end));
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
