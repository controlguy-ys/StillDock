'use strict';
/**
 * Theme loading and tone resolution.
 *
 * Content and block renderers never name a color directly. They name a semantic
 * "tone" (accent, good, risk, ...) which resolves to a PowerPoint scheme color, so
 * changing config/theme.json restyles the whole deck in one place.
 */
const fs = require('fs');

const HEX = /^[0-9A-Fa-f]{6}$/;

function loadThemeFile(file) {
  const theme = JSON.parse(fs.readFileSync(file, 'utf8'));
  validateTheme(theme, file);
  return theme;
}

function validateTheme(theme, file) {
  const required = ['name', 'page', 'fonts', 'colors', 'tones', 'schemeToSlot', 'grid', 'type', 'shape', 'shadow', 'code', 'measure'];
  for (const key of required) {
    if (theme[key] === undefined) throw new Error(`${file}: missing "${key}"`);
  }
  for (const [slot, value] of Object.entries(theme.colors)) {
    if (!HEX.test(value)) throw new Error(`${file}: colors.${slot} must be six hex digits without "#" (got ${JSON.stringify(value)})`);
  }
  for (const [tone, schemeKey] of Object.entries(theme.tones)) {
    if (!theme.schemeToSlot[schemeKey]) throw new Error(`${file}: tones.${tone} points to unknown scheme key "${schemeKey}"`);
  }
  if (!HEX.test(theme.shadow.color)) throw new Error(`${file}: shadow.color must be six hex digits`);
}

/**
 * @param {object} theme  parsed theme.json
 * @param {object} schemeColor  pptxgenjs `pres.SchemeColor`
 */
function createPalette(theme, schemeColor) {
  function schemeKeyOf(tone) {
    if (theme.tones[tone]) return theme.tones[tone];
    if (theme.schemeToSlot[tone]) return tone;
    throw new Error(`Unknown tone "${tone}". Known tones: ${Object.keys(theme.tones).join(', ')}`);
  }
  return {
    /** Scheme color for shape/text options that accept theme colors. */
    scheme: (tone) => schemeColor[schemeKeyOf(tone)],
    /** Hex color for hex-only options (shadow, rasterized icons). */
    hex: (tone) => theme.colors[theme.schemeToSlot[schemeKeyOf(tone)]],
  };
}

module.exports = { loadThemeFile, createPalette };
