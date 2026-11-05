'use strict';
/**
 * react-icons → PNG data URI for pptxgenjs `addImage({ data })`.
 * The icon library and raster size are parameters (config/build.json, theme.shape.iconPx).
 */
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const sharp = require('sharp');

function createIconRenderer({ library, px }) {
  const lib = require(library);
  const cache = new Map();

  function assertExists(name) {
    if (!lib[name]) throw new Error(`Icon "${name}" not found in ${library}`);
  }

  async function png(name, hex) {
    const key = `${name}:${hex}`;
    if (cache.has(key)) return cache.get(key);
    assertExists(name);
    const svg = renderToStaticMarkup(React.createElement(lib[name], { size: px, color: `#${hex}` }));
    const buf = await sharp(Buffer.from(svg)).resize(px, px).png().toBuffer();
    const data = `image/png;base64,${buf.toString('base64')}`;
    cache.set(key, data);
    return data;
  }

  return { png, assertExists };
}

module.exports = { createIconRenderer };
