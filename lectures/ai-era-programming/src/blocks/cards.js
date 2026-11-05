'use strict';
/** Card-based blocks: agenda, profile, stats, cards. */

function splitRow(box, n, gap) {
  const w = (box.w - (n - 1) * gap) / n;
  return Array.from({ length: n }, (_, i) => ({ x: box.x + i * (w + gap), y: box.y, w, h: box.h }));
}

async function agenda(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const A = theme.blocks.agenda;
  const n = data.items.length;
  const rowH = (box.h - (n - 1) * theme.shape.listGap) / n;
  const questionX = box.x + A.pad + A.labelW;
  const descX = box.x + box.w * A.descFrac;
  for (const [i, item] of data.items.entries()) {
    const r = { x: box.x, y: box.y + i * (rowH + theme.shape.listGap), w: box.w, h: rowH };
    prim.card(slide, r, { name: 'agenda-row' });
    prim.text(slide, { x: box.x + A.pad, y: r.y, w: A.labelW, h: r.h }, `${data.label}${i + 1}`, {
      tone: 'accent', fontSize: A.labelSize, bold: true, valign: 'middle', name: 'agenda-label',
    });
    prim.text(slide, { x: questionX, y: r.y, w: descX - questionX - A.pad, h: r.h }, item.question, {
      fontSize: A.questionSize, bold: true, valign: 'middle', name: 'agenda-q',
    });
    prim.text(slide, { x: descX, y: r.y, w: box.x + box.w - A.pad - descX, h: r.h }, item.desc, {
      tone: 'ink2', fontSize: A.descSize, valign: 'middle', name: 'agenda-desc',
    });
  }
}

async function profile(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const P = theme.blocks.profile;
  const T = theme.type;
  prim.card(slide, box, { name: 'profile-card' });
  const x = box.x + P.pad;
  const w = box.w - 2 * P.pad;
  let y = box.y + P.pad;

  prim.badge(slide, { x, y, d: P.avatar, label: data.initials, tone: 'ink', fontSize: P.initialsSize, name: 'avatar' });
  const nameX = x + P.avatar + P.nameGap;
  prim.text(slide, { x: nameX, y, w: x + w - nameX, h: P.avatar }, [
    { text: data.name, options: { fontSize: P.nameSize, bold: true, color: palette.scheme('ink'), breakLine: true } },
    { text: data.nameEn, options: { fontSize: T.body, color: palette.scheme('muted') } },
  ], { valign: 'middle', name: 'profile-name' });
  y += P.avatar + P.pad;

  for (const line of data.lines) {
    prim.text(slide, { x, y, w: P.labelW, h: P.lineH }, line.label, { tone: 'accent', fontSize: P.labelSize, bold: true, valign: 'middle', name: 'profile-label' });
    prim.text(slide, { x: x + P.labelW, y, w: w - P.labelW, h: P.lineH }, line.text, { fontSize: P.lineSize, valign: 'middle', name: 'profile-line' });
    y += P.lineH + theme.shape.listGap;
  }

  const chipH = theme.shape.chipH;
  const gap = theme.blocks.chips.gap;
  // Lay chips out bottom-up so the block always ends on the card's inner bottom edge.
  const rows = [];
  let row = [];
  let rowW = 0;
  for (const label of data.chips) {
    const cw = prim.pillWidth(label, T.caption);
    if (row.length && rowW + gap + cw > w) {
      rows.push(row);
      row = [];
      rowW = 0;
    }
    row.push({ label, cw });
    rowW += (row.length > 1 ? gap : 0) + cw;
  }
  if (row.length) rows.push(row);
  let cy = box.y + box.h - P.pad - rows.length * chipH - (rows.length - 1) * gap;
  if (cy < y) ctx.warnings.push(`[${ctx.slideId}] profile chips overlap profile lines`);
  for (const r of rows) {
    let cx = x;
    for (const chip of r) {
      prim.pill(slide, { x: cx, y: cy, label: chip.label, tone: 'ink2', outline: true, fontSize: T.caption, bold: false, name: 'profile-chip' });
      cx += chip.cw + gap;
    }
    cy += chipH + gap;
  }
}

async function stats(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const S = theme.blocks.stats;
  const T = theme.type;
  for (const [i, cell] of splitRow(box, data.items.length, theme.grid.gap).entries()) {
    const item = data.items[i];
    prim.card(slide, cell, { name: 'stat-card' });
    const inner = { x: cell.x + S.pad, w: cell.w - 2 * S.pad };
    prim.text(slide, { ...inner, y: cell.y + S.pad, h: S.valueH }, [
      { text: item.value, options: { fontSize: T.stat, bold: true, color: palette.scheme('accent') } },
      { text: ` ${item.unit}`, options: { fontSize: S.unitSize, bold: true, color: palette.scheme('ink') } },
    ], { valign: 'bottom', name: 'stat-value' });
    const ly = cell.y + S.pad + S.valueH + S.pad / 2;
    prim.text(slide, { ...inner, y: ly, h: cell.y + cell.h - S.pad - ly }, item.label, { tone: 'ink2', fontSize: T.small, name: 'stat-label' });
  }
}

async function cards(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const K = theme.blocks.cards;
  const T = theme.type;
  const gap = data.arrows ? K.arrowGap : theme.grid.gap;
  const cells = splitRow(box, data.columns || data.items.length, gap);
  const emphasized = new Set(data.emphasize || []);
  // Same description height on every card so footers line up across the row.
  const descLines = Math.max(...data.items.map((it) => ctx.measure.lineCount(it.desc, K.descSize, cells[0].w - 2 * K.pad)));

  for (const [i, item] of data.items.entries()) {
    const c = cells[i];
    const dark = emphasized.has(i);
    const tones = dark ? { text: 'paper', sub: 'paper2', muted: 'paper2' } : { text: 'ink', sub: 'ink2', muted: 'muted' };
    prim.card(slide, c, { tone: dark ? 'ink' : 'paper', name: 'card' });
    const inner = { x: c.x + K.pad, w: c.w - 2 * K.pad };

    if (data.compact) {
      const d = K.compactIcon;
      let y = c.y + K.pad;
      await prim.iconCircle(slide, { x: inner.x, y, d, icon: item.icon, tone: 'accent', alt: item.title });
      y += d + K.pad / 2;
      prim.text(slide, { ...inner, y, h: ctx.lh(K.compactTitleSize) }, item.title, { tone: tones.text, fontSize: K.compactTitleSize, bold: true, name: 'card-title' });
      y += ctx.lh(K.compactTitleSize);
      prim.text(slide, { ...inner, y, h: c.y + c.h - K.pad - y }, item.desc, { tone: tones.sub, fontSize: T.small, name: 'card-desc' });
    } else {
      let y = c.y + K.pad;
      if (item.tag) {
        prim.pill(slide, { x: inner.x, y, label: item.tag, tone: dark ? 'highlight' : 'accent', textTone: dark ? 'ink' : 'paper', h: K.tagH, fontSize: T.small, name: 'card-tag' });
      }
      const d = theme.shape.iconCircle;
      await prim.iconCircle(slide, { x: inner.x + inner.w - d, y, d, icon: item.icon, tone: dark ? 'highlight' : 'accent', variant: dark ? 'solid' : 'tint', alt: item.title });
      y += d + K.pad / 2;
      prim.text(slide, { ...inner, y, h: ctx.lh(K.titleSize) }, item.title, { tone: tones.text, fontSize: K.titleSize, bold: true, name: 'card-title' });
      y += ctx.lh(K.titleSize);
      const descH = ctx.lh(K.descSize, descLines);
      prim.text(slide, { ...inner, y, h: descH }, item.desc, { tone: tones.sub, fontSize: K.descSize, name: 'card-desc' });
      y += descH;


      // Bottom-anchored footer: rule, role label + text, example line.
      const footH = ctx.lh(T.caption);
      const roleH = ctx.lh(T.body);
      const labelH = ctx.lh(T.caption);
      let by = c.y + c.h - K.pad - footH;
      if (item.foot) prim.text(slide, { ...inner, y: by, h: footH }, item.foot, { tone: tones.muted, fontSize: T.caption, name: 'card-foot' });
      if (item.role) {
        by -= roleH + K.pad / 2;
        prim.text(slide, { ...inner, y: by, h: roleH }, item.role, { tone: tones.text, fontSize: T.body, bold: true, name: 'card-role' });
        by -= labelH;
        prim.text(slide, { ...inner, y: by, h: labelH }, data.roleLabel, { tone: dark ? 'highlight' : 'accent', fontSize: T.caption, bold: true, name: 'card-role-label' });
      }
      prim.rule(slide, { x: inner.x, y: by - K.pad / 2, w: inner.w, tone: dark ? 'paper2' : 'muted', width: theme.shape.hairline, transparency: theme.tint.rule, name: 'card-rule' });
      if (by - K.pad / 2 < y) ctx.warnings.push(`[${ctx.slideId}] card "${item.title}" footer overlaps body`);
    }

    if (data.arrows && i < data.items.length - 1) {
      const aw = gap * theme.shape.arrowFrac;
      prim.arrow(slide, { x: c.x + c.w + (gap - aw) / 2, y: c.y + c.h / 2, w: aw, tone: 'accent', name: 'card-arrow' });
    }
  }
}

module.exports = { agenda, profile, stats, cards, splitRow };
