'use strict';
/** Contrast blocks: quoteCard, compareFlow, compareStatements, shiftTable, statements, contact. */

async function quoteCard(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const Q = theme.blocks.quoteCard;
  const T = theme.type;
  prim.card(slide, box, { tone: 'paper', line: data.tone, name: 'quote-card' });
  const inner = { x: box.x + Q.pad, w: box.w - 2 * Q.pad };
  let y = box.y + Q.pad;
  prim.pill(slide, { x: inner.x, y, label: data.label, tone: data.tone, h: Q.labelH, fontSize: T.small, name: 'quote-label' });
  y += Q.labelH + Q.pad / 2;
  prim.text(slide, { ...inner, y, h: Q.quoteH }, data.quote, { fontSize: Q.quoteSize, bold: true, valign: 'middle', name: 'quote' });
  y += Q.quoteH;
  prim.text(slide, { ...inner, y, h: Q.flowH }, data.flow.join(Q.joiner), {
    tone: data.tone, fontSize: Q.flowSize, bold: true, fontFace: theme.fonts.code, valign: 'middle', name: 'quote-flow',
  });
  y += Q.flowH + Q.pad / 2;
  prim.rule(slide, { x: inner.x, y, w: inner.w, tone: 'muted', width: theme.shape.hairline, transparency: theme.tint.rule, name: 'quote-rule' });
  y += Q.pad / 2;
  const runs = data.bullets.map((b, i) => ({
    text: b,
    options: {
      bullet: true, fontSize: T.body, color: ctx.palette.scheme('ink2'), paraSpaceAfter: T.body / 2,
      ...(i < data.bullets.length - 1 ? { breakLine: true } : {}),
    },
  }));
  prim.text(slide, { ...inner, y, h: box.y + box.h - Q.pad - y }, runs, { name: 'quote-bullets' });
}

async function compareFlow(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const F = theme.blocks.compareFlow;
  const chipH = theme.shape.chipH;
  const gap = theme.grid.gap;
  const n = data.rows.length;
  const rowH = (box.h - (n - 1) * gap) / n;
  for (const [i, row] of data.rows.entries()) {
    const r = { x: box.x, y: box.y + i * (rowH + gap), w: box.w, h: rowH };
    const solid = row.tone !== 'muted';
    prim.card(slide, r, { name: 'flow-row' });
    prim.text(slide, { x: r.x + F.pad, y: r.y + F.pad, w: r.w - 2 * F.pad, h: F.labelH }, row.label, {
      tone: solid ? row.tone : 'muted', fontSize: theme.type.h3, bold: true, valign: 'middle', name: 'flow-label',
    });
    // Chip chain with arrows, wrapping onto new lines when needed.
    const maxX = r.x + r.w - F.pad;
    let x = r.x + F.pad;
    let y = r.y + F.pad + F.labelH + F.pad / 2;
    for (const [j, label] of row.flow.entries()) {
      const w = prim.pillWidth(label, F.chipSize);
      if (x > r.x + F.pad && x + w > maxX) {
        x = r.x + F.pad;
        y += chipH + gap / 2;
      }
      prim.pill(slide, { x, y, label, tone: solid ? row.tone : 'ink2', outline: !solid, fontSize: F.chipSize, bold: solid, name: 'flow-chip' });
      x += w;
      if (j < row.flow.length - 1) {
        prim.arrow(slide, { x: x + F.arrowW * (1 - theme.shape.arrowFrac) / 2, y: y + chipH / 2, w: F.arrowW * theme.shape.arrowFrac, tone: solid ? row.tone : 'muted', name: 'flow-arrow' });
        x += F.arrowW;
      }
    }
    if (y + chipH > r.y + r.h - F.pad / 2) ctx.warnings.push(`[${ctx.slideId}] compareFlow row "${row.label}" overflows`);
  }
}

async function compareStatements(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const S = theme.blocks.compareStatements;
  const n = data.items.length;
  const w = (box.w - (n - 1) * S.arrowGap) / n;
  for (const [i, item] of data.items.entries()) {
    const c = { x: box.x + i * (w + S.arrowGap), y: box.y, w, h: box.h };
    prim.card(slide, c, { tone: 'paper', line: item.tone, name: 'statement-card' });
    const inner = { x: c.x + S.pad, w: c.w - 2 * S.pad };
    prim.text(slide, { ...inner, y: c.y + S.pad, h: S.labelH }, item.label, { tone: item.tone, fontSize: theme.type.small, bold: true, valign: 'middle', name: 'statement-label' });
    const ty = c.y + S.pad + S.labelH;
    prim.text(slide, { ...inner, y: ty, h: c.y + c.h - S.pad - ty }, [
      { text: item.text, options: { fontSize: theme.type.statement, bold: true, color: palette.scheme(item.strike ? 'muted' : 'ink'), ...(item.strike ? { strike: 'sngStrike' } : {}) } },
    ], { valign: 'middle', name: 'statement-text' });
    if (i < n - 1) {
      const aw = S.arrowGap * theme.shape.arrowFrac;
      prim.arrow(slide, { x: c.x + c.w + (S.arrowGap - aw) / 2, y: c.y + c.h / 2, w: aw, tone: 'accent', width: theme.shape.lineW * 2, name: 'statement-arrow' });
    }
  }
}

async function shiftTable(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const S = theme.blocks.shiftTable;
  const T = theme.type;
  const fromX = box.x + S.pad + S.icon + S.pad;
  const fromW = box.w * S.fromFrac;
  const arrowX = fromX + fromW;
  const toX = arrowX + S.arrowW;
  const tagW = box.w * S.tagFrac;
  const tagX = box.x + box.w - S.pad - tagW;
  const toW = tagX - toX - S.pad;

  const header = [[fromX, fromW, data.header.from], [toX, toW, data.header.to], [tagX, tagW, data.header.tag]];
  for (const [x, w, label] of header) {
    prim.text(slide, { x, y: box.y, w, h: S.headerH }, label, { tone: 'muted', fontSize: T.small, bold: true, valign: 'middle', name: 'shift-header' });
  }
  const top = box.y + S.headerH + S.gap;
  const n = data.rows.length;
  const rowH = (box.y + box.h - top - (n - 1) * S.gap) / n;
  for (const [i, row] of data.rows.entries()) {
    const r = { x: box.x, y: top + i * (rowH + S.gap), w: box.w, h: rowH };
    prim.card(slide, r, { name: 'shift-row' });
    await prim.iconCircle(slide, { x: r.x + S.pad, y: r.y + (r.h - S.icon) / 2, d: S.icon, icon: row.icon, tone: 'accent', alt: row.to });
    prim.text(slide, { x: fromX, y: r.y, w: fromW, h: r.h }, row.from, { tone: 'muted', fontSize: T.body, valign: 'middle', name: 'shift-from' });
    const aw = S.arrowW * theme.shape.arrowFrac;
    prim.arrow(slide, { x: arrowX + (S.arrowW - aw) / 2 - S.pad / 2, y: r.y + r.h / 2, w: aw, tone: 'accent', name: 'shift-arrow' });
    prim.text(slide, { x: toX, y: r.y, w: toW, h: r.h }, row.to, { fontSize: T.h3, bold: true, valign: 'middle', name: 'shift-to' });
    const pw = prim.pillWidth(row.tag, T.small);
    prim.pill(slide, { x: tagX + tagW - pw, y: r.y + (r.h - theme.shape.chipH) / 2, label: row.tag, tone: 'ink2', outline: true, fontSize: T.small, name: 'shift-tag' });
  }
}

async function statements(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const S = theme.blocks.statements;
  const n = data.items.length;
  const rowH = box.h / n;
  for (const [i, item] of data.items.entries()) {
    const y = box.y + i * rowH;
    prim.text(slide, { x: box.x, y, w: S.numberW, h: rowH }, String(i + 1).padStart(2, '0'), {
      tone: 'accent', fontSize: S.numberSize, bold: true, valign: 'middle', name: 'statement-no',
    });
    prim.text(slide, { x: box.x + S.numberW, y, w: box.w - S.numberW, h: rowH }, item, {
      tone: 'paper', emphTone: 'highlight', fontSize: theme.type.statement, valign: 'middle', name: 'statement',
    });
    if (i < n - 1) {
      prim.rule(slide, { x: box.x, y: y + rowH, w: box.w, tone: 'paper2', width: theme.shape.hairline, transparency: theme.tint.rule, name: 'statement-rule' });
    }
  }
}

async function contact(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const K = theme.blocks.contact;
  prim.card(slide, box, { tone: 'ink2', withShadow: false, name: 'contact-card' });
  const inner = { x: box.x + K.pad, w: box.w - 2 * K.pad };
  let y = box.y + K.pad;
  prim.text(slide, { ...inner, y, h: K.ctaH }, data.cta, { tone: 'highlight', fontSize: K.ctaSize, bold: true, valign: 'middle', name: 'contact-cta' });
  y += K.ctaH + K.pad / 2;
  prim.text(slide, { ...inner, y, h: ctx.lh(K.nameSize) }, data.name, { tone: 'paper', fontSize: K.nameSize, bold: true, name: 'contact-name' });
  y += ctx.lh(K.nameSize);
  prim.text(slide, { ...inner, y, h: ctx.lh(K.lineSize, data.lines.length) }, data.lines.join('\n'), { tone: 'paper2', fontSize: K.lineSize, name: 'contact-lines' });
  if (data.tagline) {
    const lines = [].concat(data.tagline);
    const tagH = ctx.lh(K.taglineSize, lines.length);
    prim.text(slide, { ...inner, y: box.y + box.h - K.pad - tagH, h: tagH }, lines.join('\n'), {
      tone: 'highlight', fontSize: K.taglineSize, bold: true, valign: 'bottom', name: 'contact-tagline',
    });
  }
}

module.exports = { quoteCard, compareFlow, compareStatements, shiftTable, statements, contact };
