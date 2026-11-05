'use strict';
/** Content loading + validation against the known sections, layouts and block types. */
const fs = require('fs');

function loadContent(file, { layouts, blockTypes }) {
  const content = JSON.parse(fs.readFileSync(file, 'utf8'));
  const errors = [];
  const sectionIds = new Set((content.sections || []).map((s) => s.id));
  const seenIds = new Set();
  const sectionOrder = [];

  for (const [i, s] of (content.slides || []).entries()) {
    const where = `slides[${i}]${s.id ? ` (${s.id})` : ''}`;
    if (!s.id) errors.push(`${where}: missing id`);
    else if (seenIds.has(s.id)) errors.push(`${where}: duplicate id`);
    seenIds.add(s.id);
    if (!sectionIds.has(s.section)) errors.push(`${where}: unknown section "${s.section}"`);
    if (!layouts.includes(s.layout)) errors.push(`${where}: unknown layout "${s.layout}" (known: ${layouts.join(', ')})`);
    if (!s.title) errors.push(`${where}: missing title`);
    for (const [j, b] of (s.blocks || []).entries()) {
      if (!blockTypes.includes(b.type)) errors.push(`${where}.blocks[${j}]: unknown type "${b.type}"`);
    }
    if (sectionOrder[sectionOrder.length - 1] !== s.section) {
      if (sectionOrder.includes(s.section)) errors.push(`${where}: section "${s.section}" is not contiguous`);
      sectionOrder.push(s.section);
    }
  }
  if (!content.slides || content.slides.length === 0) errors.push('no slides');
  if (errors.length) throw new Error(`Invalid content ${file}:\n  - ${errors.join('\n  - ')}`);
  return content;
}

module.exports = { loadContent };
