'use strict';
/**
 * Drawing primitives shared by every block: cards, pills, badges, icon circles,
 * arrows, rules and the dark message band. All sizes default to theme.shape /
 * theme.type values, all colors are tones resolved through the palette.
 */
const { toRuns, stripMarkup } = require('./richtext');

function createPrimitives(env) {
  const { pres, theme, palette, measure, icons, naming, warnings } = env;
  const S = pres.shapes;
  const T = theme.type;
  const SH = theme.shape;
  const LINE_SPACING = theme.measure.lineSpacing;

  const shadow = () => ({ ...theme.shadow });
  const nm = (prefix) => naming.next(prefix);
  const noLine = () => ({ type: 'none' });

  function checkFit(slideId, plain, fontSize, box) {
    const lines = measure.lineCount(plain, fontSize, box.w);
    const needed = (lines * fontSize * LINE_SPACING) / 72;
    if (needed > box.h + theme.measure.fitTolerance) {
      warnings.push(`[${slideId}] text may overflow (${needed.toFixed(2)}" > ${box.h.toFixed(2)}"): "${plain.slice(0, 40)}"`);
    }
  }

  /**
   * Text box. `content` is a markup string (see richtext.js) or a prepared runs array.
   * opts: tone, emphTone, fontSize, bold, italic, fontFace, align, valign, name, + any pptxgenjs text option.
   */
  function text(slide, box, content, opts = {}) {
    const { tone = 'ink', emphTone = 'accent', fontSize = T.body, bold = false, italic, fontFace, name, transparency, ...rest } = opts;
    const base = { fontSize, bold, color: palette.scheme(tone), lang: theme.lang };
    if (italic) base.italic = true;
    if (fontFace) base.fontFace = fontFace;
    if (transparency) base.transparency = transparency;
    const runs = Array.isArray(content)
      ? content
      : toRuns(content, base, { bold: true, color: palette.scheme(emphTone) });
    const plain = Array.isArray(content) ? content.map((r) => r.text).join('') : stripMarkup(content);
    checkFit(slide._deckSlideId, plain, fontSize, box);
    slide.addText(runs, {
      x: box.x, y: box.y, w: box.w, h: box.h,
      margin: 0, valign: 'top', isTextBox: true, bullet: false,
      objectName: nm(name || 'text'),
      ...rest,
    });
  }

  function card(slide, box, { tone = 'paper', line, transparency, radius = SH.radius, withShadow = true, name } = {}) {
    slide.addShape(S.ROUNDED_RECTANGLE, {
      x: box.x, y: box.y, w: box.w, h: box.h,
      rectRadius: Math.min(radius, Math.min(box.w, box.h) / 2),
      fill: { color: palette.scheme(tone), ...(transparency ? { transparency } : {}) },
      line: line ? { color: palette.scheme(line), width: 1 } : noLine(),
      ...(withShadow ? { shadow: shadow() } : {}),
      objectName: nm(name || 'card'),
    });
  }

  function pillWidth(label, fontSize = T.small) {
    return measure.width(label, fontSize) + 2 * SH.chipPadX;
  }

  /** Rounded pill with a label; returns its width so callers can lay out rows. */
  function pill(slide, { x, y, label, tone = 'accent', textTone = 'paper', outline = false, fontSize = T.small, h = SH.chipH, bold = true, w, name }) {
    const width = w || pillWidth(label, fontSize);
    slide.addText(label, {
      shape: S.ROUNDED_RECTANGLE, x, y, w: width, h, rectRadius: h / 2,
      ...(outline ? {} : { fill: { color: palette.scheme(tone) } }),
      line: outline ? { color: palette.scheme(tone), width: 1 } : noLine(),
      color: palette.scheme(outline ? tone : textTone),
      fontSize, bold, align: 'center', valign: 'middle', margin: 0, wrap: false, isTextBox: true, lang: theme.lang,
      objectName: nm(name || 'pill'),
    });
    return width;
  }

  function badge(slide, { x, y, d = SH.badge, label, tone = 'accent', textTone = 'paper', fontSize = T.small, name }) {
    slide.addText(String(label), {
      shape: S.OVAL, x, y, w: d, h: d,
      fill: { color: palette.scheme(tone) }, line: noLine(),
      color: palette.scheme(textTone), fontSize, bold: true,
      align: 'center', valign: 'middle', margin: 0, isTextBox: true,
      objectName: nm(name || 'badge'),
    });
  }

  /** Icon on a tinted (default) or solid circle. */
  async function iconCircle(slide, { x, y, d = SH.iconCircle, icon, tone = 'accent', variant = 'tint', alt, name }) {
    const solid = variant === 'solid';
    slide.addShape(S.OVAL, {
      x, y, w: d, h: d,
      fill: { color: palette.scheme(tone), ...(solid ? {} : { transparency: theme.tint.soft }) },
      line: noLine(),
      objectName: nm(name || 'icon-bg'),
    });
    const size = d * SH.iconScale;
    const data = await icons.png(icon, palette.hex(solid ? 'paper' : tone));
    slide.addImage({
      data, x: x + (d - size) / 2, y: y + (d - size) / 2, w: size, h: size,
      altText: alt || icon, objectName: nm(name || 'icon'),
    });
  }

  function arrow(slide, { x, y, w, h = 0, flipH = false, tone = 'muted', width = SH.lineW, name }) {
    slide.addShape(S.LINE, {
      x, y, w, h, ...(flipH ? { flipH: true } : {}),
      line: { color: palette.scheme(tone), width, endArrowType: 'triangle' },
      objectName: nm(name || 'arrow'),
    });
  }

  function rule(slide, { x, y, w = 0, h = 0, tone = 'muted', width = SH.lineW, dash, transparency, name }) {
    slide.addShape(S.LINE, {
      x, y, w, h,
      line: { color: palette.scheme(tone), width, ...(dash ? { dashType: dash } : {}), ...(transparency ? { transparency } : {}) },
      objectName: nm(name || 'rule'),
    });
  }

  /** Dark rounded message band with emphasis runs (the deck's key-message motif). */
  function band(slide, box, markup) {
    card(slide, box, { tone: 'ink', withShadow: false, name: 'band' });
    const pad = SH.cardPad * 1.5;
    text(slide, { x: box.x + pad, y: box.y, w: box.w - 2 * pad, h: box.h }, markup, {
      tone: 'paper', emphTone: 'highlight', fontSize: T.band, valign: 'middle', name: 'band-text',
    });
  }

  return { text, card, pill, pillWidth, badge, iconCircle, arrow, rule, band, shadow };
}

module.exports = { createPrimitives };
