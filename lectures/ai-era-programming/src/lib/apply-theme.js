'use strict';
/**
 * pptxgenjs writes Office's stock palette and leaves East-Asian theme fonts empty.
 * After writeFile(), patch ppt/theme/theme1.xml with the theme's 12 colors, its name,
 * and the head/body fonts for both Latin and East-Asian (Hangul) text.
 */
const fs = require('fs');
const JSZip = require('jszip');

const SLOTS = ['dk1', 'lt1', 'dk2', 'lt2', 'accent1', 'accent2', 'accent3', 'accent4', 'accent5', 'accent6', 'hlink', 'folHlink'];
const THEME_PART = 'ppt/theme/theme1.xml';

const xmlAttr = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function patchFontBlock(block, face, scripts) {
  let out = block.replace(/<a:ea typeface="[^"]*"\s*\/>/, `<a:ea typeface="${xmlAttr(face)}"/>`);
  for (const script of scripts) {
    out = out.replace(new RegExp(`<a:font script="${script}" typeface="[^"]*"\\s*/>`), `<a:font script="${script}" typeface="${xmlAttr(face)}"/>`);
  }
  return out;
}

function patchThemeXml(xml, theme) {
  const name = xmlAttr(theme.name);
  const scheme = `<a:clrScheme name="${name}">`
    + SLOTS.map((k) => `<a:${k}><a:srgbClr val="${theme.colors[k].toUpperCase()}"/></a:${k}>`).join('')
    + '</a:clrScheme>';
  const scripts = theme.fonts.eaScripts || [];
  const out = xml
    .replace(/<a:clrScheme\b[\s\S]*?<\/a:clrScheme>/, () => scheme)
    .replace(/<a:majorFont>[\s\S]*?<\/a:majorFont>/, (b) => patchFontBlock(b, theme.fonts.head, scripts))
    .replace(/<a:minorFont>[\s\S]*?<\/a:minorFont>/, (b) => patchFontBlock(b, theme.fonts.body, scripts))
    .replace(/(<a:(?:theme|fontScheme)\b[^>]*?\bname=")[^"]*"/g, (_, head) => `${head}${name}"`);
  if (!out.includes(scheme)) throw new Error(`${THEME_PART} has no <a:clrScheme> to replace`);
  return out;
}

async function applyTheme(deckPath, theme) {
  const zip = await JSZip.loadAsync(fs.readFileSync(deckPath));
  if (!zip.file(THEME_PART)) throw new Error(`${deckPath} has no ${THEME_PART}`);
  zip.file(THEME_PART, patchThemeXml(await zip.file(THEME_PART).async('string'), theme));

  // A scheme color passed to a hex-only option is written as <a:srgbClr val="tx1"/>; refuse such a deck.
  for (const part of Object.keys(zip.files).filter((n) => n.endsWith('.xml'))) {
    const bad = (await zip.file(part).async('string')).match(/<a:srgbClr val="((?![0-9A-Fa-f]{6}")[^"]*)"/);
    if (bad) throw new Error(`${part}: <a:srgbClr val="${bad[1]}"> is not a hex color (scheme color used in a hex-only option)`);
  }
  fs.writeFileSync(deckPath, await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' }));
}

module.exports = { applyTheme, patchThemeXml };
