'use strict';
/**
 * Minimal markup for slide copy:
 *   **emphasis**  → run styled with the caller's `emph` options (bold + accent tone)
 *   \n            → line break
 */
const EMPH = /(\*\*[^*]+\*\*)/;

function stripMarkup(text) {
  return String(text).replace(/\*\*([^*]+)\*\*/g, '$1');
}

function toRuns(text, base = {}, emph = {}) {
  const lines = String(text).split('\n');
  const runs = [];
  lines.forEach((line, li) => {
    const parts = line.split(EMPH).filter((p) => p.length > 0);
    if (parts.length === 0) parts.push(' ');
    parts.forEach((part, pi) => {
      const isEmph = part.startsWith('**') && part.endsWith('**') && part.length > 4;
      const options = { ...base, ...(isEmph ? emph : {}) };
      if (pi === parts.length - 1 && li < lines.length - 1) options.breakLine = true;
      runs.push({ text: isEmph ? part.slice(2, -2) : part, options });
    });
  });
  return runs;
}

module.exports = { toRuns, stripMarkup };
