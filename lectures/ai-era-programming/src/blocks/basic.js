'use strict';
/** Small inline blocks: chips row, presenter line, code window. */

async function chips(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const fontSize = data.fontSize || theme.type.small;
  const h = theme.shape.chipH;
  const gap = theme.blocks.chips.gap;
  let x = box.x;
  let y = box.y;
  for (const label of data.items) {
    const w = prim.pillWidth(label, fontSize);
    if (x > box.x && x + w > box.x + box.w) {
      x = box.x;
      y += h + gap;
    }
    prim.pill(slide, { x, y, label, fontSize, tone: data.tone || 'accent', outline: data.style === 'outline', name: 'chip' });
    x += w + gap;
  }
}

async function presenter(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const P = theme.blocks.presenter;
  prim.text(slide, { x: box.x, y: box.y, w: box.w, h: P.nameH }, [
    { text: data.name, options: { fontSize: P.nameSize, bold: true, color: ctx.palette.scheme(ctx.ink.text) } },
    { text: `  ${data.nameEn}`, options: { fontSize: P.subSize, color: ctx.palette.scheme(ctx.ink.muted) } },
  ], { valign: 'middle', name: 'presenter-name' });
  prim.text(slide, { x: box.x, y: box.y + P.nameH, w: box.w, h: box.h - P.nameH }, data.role, {
    tone: ctx.ink.sub, fontSize: P.roleSize, name: 'presenter-role',
  });
}

function tokenize(line, syntax) {
  const trimmed = line.trimStart();
  if (syntax.heading.some((h) => trimmed.startsWith(h))) return [{ text: line, kind: 'heading' }];
  const cut = syntax.comment
    .map((m) => line.indexOf(m))
    .filter((i) => i >= 0)
    .reduce((a, b) => Math.min(a, b), Infinity);
  const code = cut === Infinity ? line : line.slice(0, cut);
  const comment = cut === Infinity ? '' : line.slice(cut);
  const keywords = new Set(syntax.keywords);
  const tokens = code
    .split(/(\b[A-Za-z_]+\b)/)
    .filter((t) => t.length > 0)
    .map((t) => ({ text: t, kind: keywords.has(t) ? 'keyword' : 'base' }));
  if (comment) tokens.push({ text: comment, kind: 'comment' });
  return tokens.length ? tokens : [{ text: ' ', kind: 'base' }];
}

async function code(ctx, box, data) {
  const { slide, prim, theme, palette, warnings } = ctx;
  const C = theme.code;
  const B = theme.blocks.code;
  const syntax = C.syntax[data.lang];
  if (!syntax) throw new Error(`[${ctx.slideId}] unknown code lang "${data.lang}" (theme.code.syntax)`);
  const pad = theme.shape.cardPad;

  prim.card(slide, box, { tone: ctx.surface === 'dark' ? C.fill.onDark : C.fill.onLight, withShadow: ctx.surface !== 'dark', name: 'code-window' });
  C.dotTones.forEach((tone, i) => {
    slide.addShape(ctx.pres.shapes.OVAL, {
      x: box.x + pad + i * (C.dotD + B.dotGap), y: box.y + (C.barH - C.dotD) / 2, w: C.dotD, h: C.dotD,
      fill: { color: palette.scheme(tone) }, line: { type: 'none' }, objectName: ctx.naming.next('code-dot'),
    });
  });
  const labelX = box.x + pad + C.dotTones.length * (C.dotD + B.dotGap) + pad / 2;
  prim.text(slide, { x: labelX, y: box.y, w: box.x + box.w - pad - labelX, h: C.barH }, data.title, {
    tone: C.tones.label, fontSize: B.labelSize, fontFace: theme.fonts.code, valign: 'middle', transparency: C.commentTransparency, name: 'code-title',
  });
  prim.rule(slide, { x: box.x, y: box.y + C.barH, w: box.w, tone: C.tones.label, width: theme.shape.hairline, transparency: theme.tint.rule, name: 'code-bar' });

  const runs = [];
  data.lines.forEach((line, li) => {
    const tokens = tokenize(line, syntax);
    tokens.forEach((tok, ti) => {
      const options = {
        fontFace: theme.fonts.code, fontSize: theme.type.code,
        color: palette.scheme(C.tones[tok.kind]),
        bold: tok.kind === 'keyword' || tok.kind === 'heading',
      };
      if (tok.kind === 'comment') options.transparency = C.commentTransparency;
      if (ti === tokens.length - 1 && li < data.lines.length - 1) options.breakLine = true;
      runs.push({ text: tok.text, options });
    });
  });
  const textBox = { x: box.x + pad, y: box.y + C.barH + B.textInsetY, w: box.w - 2 * pad, h: box.h - C.barH - B.textInsetY - pad / 2 };
  prim.text(slide, textBox, runs, { lineSpacingMultiple: C.lineHeight, name: 'code-text' });

  const needH = (data.lines.length * theme.type.code * C.lineHeight * theme.measure.lineSpacing) / 72;
  const widest = Math.max(...data.lines.map((l) => (l.length * theme.type.code * theme.measure.codeEm) / 72));
  if (needH > textBox.h) warnings.push(`[${ctx.slideId}] code "${data.title}" needs ${needH.toFixed(2)}" > ${textBox.h.toFixed(2)}"`);
  if (widest > textBox.w) warnings.push(`[${ctx.slideId}] code "${data.title}" line ${widest.toFixed(2)}" wider than ${textBox.w.toFixed(2)}"`);
}

module.exports = { chips, presenter, code };
