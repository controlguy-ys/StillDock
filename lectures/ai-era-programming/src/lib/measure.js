'use strict';
/**
 * Approximate text metrics, used to size pills and to warn about likely overflow.
 * Character-class widths (in em) come from theme.measure so they can be tuned per font.
 */
function createMeasurer(metrics) {
  const isWide = (cp) =>
    (cp >= 0x1100 && cp <= 0x11ff) || // Hangul Jamo
    (cp >= 0x2010 && cp <= 0x2bff) || // punctuation, arrows, symbols (dash, quotes, →)
    (cp >= 0x2e80 && cp <= 0x9fff) || // CJK
    (cp >= 0xac00 && cp <= 0xd7af) || // Hangul syllables
    (cp >= 0xf900 && cp <= 0xfaff) ||
    (cp >= 0xff00 && cp <= 0xffef);

  function charEm(ch) {
    const cp = ch.codePointAt(0);
    if (isWide(cp)) return metrics.cjk;
    if (ch === ' ') return metrics.space;
    if (ch >= 'A' && ch <= 'Z') return metrics.upper;
    if (ch >= 'a' && ch <= 'z') return metrics.lower;
    if (ch >= '0' && ch <= '9') return metrics.digit;
    return metrics.punct;
  }

  /** Width in inches of a single line of text at `pt`. */
  function width(text, pt) {
    let em = 0;
    for (const ch of String(text)) em += charEm(ch);
    return (em * pt * metrics.slack) / 72;
  }

  /** Estimated wrapped line count (word wrap on spaces, hard breaks on \n). */
  function lineCount(text, pt, boxW) {
    let total = 0;
    for (const para of String(text).split('\n')) {
      let lines = 1;
      let cur = 0;
      for (const word of para.split(' ')) {
        const ww = width(word, pt);
        const sp = cur > 0 ? width(' ', pt) : 0;
        if (cur > 0 && cur + sp + ww > boxW) {
          lines += 1;
          cur = ww;
        } else {
          cur += sp + ww;
        }
        while (cur > boxW) { // a single word longer than the box
          lines += 1;
          cur -= boxW;
        }
      }
      total += lines;
    }
    return total;
  }

  return { width, lineCount };
}

module.exports = { createMeasurer };
