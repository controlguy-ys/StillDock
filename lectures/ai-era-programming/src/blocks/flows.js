'use strict';
/** Process/sequence blocks: steps, itemList, timeline, staircase. */

function stepBoxes(box, n, gap) {
  const w = (box.w - (n - 1) * gap) / n;
  return Array.from({ length: n }, (_, i) => ({ x: box.x + i * (w + gap), w }));
}

async function steps(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const P = theme.blocks.steps;
  const T = theme.type;
  const chipH = theme.shape.chipH;
  const n = data.items.length;
  const cols = stepBoxes(box, n, P.arrowGap);
  const highlight = new Set(data.highlight || []);
  const stepH = data.brackets ? box.h - chipH - P.bracketGap : box.h;
  const d = P.icon;

  // Vertical stack inside a step card, centred as a group.
  const stackH = d + P.itemGap + P.titleH + P.descH;
  for (const [i, item] of data.items.entries()) {
    const c = { x: cols[i].x, y: box.y, w: cols[i].w, h: stepH };
    const hl = highlight.has(i);
    const hlTone = data.highlightTone || 'accent';
    prim.card(slide, c, hl
      ? { tone: hlTone, transparency: theme.tint.medium, line: hlTone, name: 'step-card' }
      : { name: 'step-card' });
    let y = c.y + Math.max(P.pad, (c.h - stackH) / 2);
    await prim.iconCircle(slide, { x: c.x + (c.w - d) / 2, y, d, icon: item.icon, tone: hl ? hlTone : 'accent', variant: hl ? 'solid' : 'tint', alt: item.title });
    y += d + P.itemGap;
    const inner = { x: c.x + P.pad, w: c.w - 2 * P.pad };
    prim.text(slide, { ...inner, y, h: P.titleH }, item.title, { fontSize: P.titleSize, bold: true, align: 'center', valign: 'middle', name: 'step-title' });
    y += P.titleH;
    prim.text(slide, { ...inner, y, h: P.descH }, item.desc, { tone: 'ink2', fontSize: T.body, align: 'center', name: 'step-desc' });

    if (i < n - 1) {
      const aw = P.arrowGap * theme.shape.arrowFrac;
      prim.arrow(slide, { x: c.x + c.w + (P.arrowGap - aw) / 2, y: c.y + c.h / 2, w: aw, tone: 'muted', name: 'step-arrow' });
    }
  }

  for (const br of data.brackets || []) {
    const x0 = cols[br.from].x;
    const x1 = cols[br.to].x + cols[br.to].w;
    prim.pill(slide, {
      x: x0, y: box.y + stepH + P.bracketGap, w: x1 - x0, label: br.label,
      tone: br.tone, textTone: 'paper', fontSize: T.small, name: 'step-bracket',
    });
  }
}

async function itemList(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const L = theme.blocks.itemList;
  const T = theme.type;
  let top = box.y;
  if (data.heading) {
    prim.text(slide, { x: box.x, y: top, w: box.w, h: L.headingH }, data.heading, {
      tone: 'muted', fontSize: L.headingSize, bold: true, valign: 'middle', name: 'list-heading',
    });
    top += L.headingH;
  }
  const listW = data.loopLabel ? box.w - L.loopW : box.w;
  const n = data.items.length;
  const rowH = (box.y + box.h - top - (n - 1) * L.gap) / n;
  const markerD = data.marker === 'icon' ? theme.shape.iconCircle : theme.shape.badge;
  const markerSlot = data.marker === 'none' ? 0 : markerD + L.pad;
  const rows = [];

  for (const [i, item] of data.items.entries()) {
    const r = { x: box.x, y: top + i * (rowH + L.gap), w: listW, h: rowH };
    rows.push(r);
    prim.card(slide, r, { name: 'list-row' });
    const my = r.y + (r.h - markerD) / 2;
    if (data.marker === 'icon') {
      await prim.iconCircle(slide, { x: r.x + L.pad, y: my, d: markerD, icon: item.icon, tone: data.tone, alt: item.title });
    } else if (data.marker === 'number') {
      prim.badge(slide, { x: r.x + L.pad, y: my, d: markerD, label: i + 1, tone: data.tone, fontSize: T.small, name: 'list-no' });
    }
    const tx = r.x + L.pad + markerSlot;
    const tw = r.x + r.w - L.pad - tx;
    if (data.inline) {
      prim.text(slide, { x: tx, y: r.y, w: L.inlineTitleW, h: r.h }, item.title, { fontSize: L.titleSize, bold: true, valign: 'middle', name: 'list-title' });
      prim.text(slide, { x: tx + L.inlineTitleW, y: r.y, w: tw - L.inlineTitleW, h: r.h }, item.desc, { tone: 'ink2', fontSize: T.body, valign: 'middle', name: 'list-desc' });
    } else if (item.desc) {
      const titleH = ctx.lh(L.titleSize, ctx.measure.lineCount(item.title, L.titleSize, tw));
      const descH = ctx.lh(T.body, ctx.measure.lineCount(item.desc, T.body, tw));
      const ty = r.y + (r.h - titleH - descH) / 2;
      prim.text(slide, { x: tx, y: ty, w: tw, h: titleH }, item.title, { fontSize: L.titleSize, bold: true, valign: 'middle', name: 'list-title' });
      prim.text(slide, { x: tx, y: ty + titleH, w: tw, h: descH }, item.desc, { tone: 'ink2', fontSize: T.body, valign: 'middle', name: 'list-desc' });
    } else {
      prim.text(slide, { x: tx, y: r.y, w: tw, h: r.h }, item.title, { fontSize: L.titleSize, bold: true, valign: 'middle', name: 'list-title' });
    }
  }

  if (data.loopLabel) {
    // Return path: last row → right → up → back into the first row.
    const first = rows[0];
    const last = rows[rows.length - 1];
    const xr = first.x + first.w + L.loopInset;
    const yTop = first.y + first.h / 2;
    const yBot = last.y + last.h / 2;
    const tone = data.loopTone || 'accent';
    prim.rule(slide, { x: last.x + last.w, y: yBot, w: L.loopInset, tone, name: 'loop-out' });
    prim.rule(slide, { x: xr, y: yTop, h: yBot - yTop, tone, name: 'loop-up' });
    prim.arrow(slide, { x: xr - L.loopInset, y: yTop, w: L.loopInset, flipH: true, tone, name: 'loop-in' });
    const labelH = box.x + box.w - xr;
    prim.text(slide, { x: xr + L.gap / 2, y: yTop, w: labelH - L.gap / 2, h: yBot - yTop }, data.loopLabel, {
      tone, fontSize: T.small, bold: true, valign: 'middle', align: 'center', vert: 'eaVert', name: 'loop-label',
    });
  }
}

async function timeline(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const L = theme.blocks.itemList;
  const M = theme.blocks.timeline;
  const T = theme.type;
  let top = box.y;
  if (data.heading) {
    prim.text(slide, { x: box.x, y: top, w: box.w, h: L.headingH }, data.heading, {
      tone: 'muted', fontSize: L.headingSize, bold: true, valign: 'middle', name: 'timeline-heading',
    });
    top += L.headingH;
  }
  const card = { x: box.x, y: top, w: box.w, h: box.y + box.h - top };
  prim.card(slide, card, { name: 'timeline-card' });
  const n = data.items.length;
  const rowH = (card.h - 2 * M.pad) / n;
  const lineX = card.x + M.pad + M.whenW + M.dot / 2;
  prim.rule(slide, { x: lineX, y: card.y + M.pad + rowH / 2, h: rowH * (n - 1), tone: 'muted', transparency: theme.tint.rule, name: 'timeline-axis' });
  const textX = lineX + M.dot / 2 + M.pad;
  const textW = card.x + card.w - M.pad - textX;
  for (const [i, item] of data.items.entries()) {
    const cy = card.y + M.pad + i * rowH + rowH / 2;
    prim.text(slide, { x: card.x + M.pad, y: cy - rowH / 2, w: M.whenW - M.pad / 2, h: rowH }, item.when, {
      tone: 'accent', fontSize: T.small, bold: true, valign: 'middle', name: 'timeline-when',
    });
    slide.addShape(ctx.pres.shapes.OVAL, {
      x: lineX - M.dot / 2, y: cy - M.dot / 2, w: M.dot, h: M.dot,
      fill: { color: ctx.palette.scheme(i === n - 1 ? 'accent' : 'paper') }, line: { color: ctx.palette.scheme('accent'), width: theme.shape.lineW },
      objectName: ctx.naming.next('timeline-dot'),
    });
    const titleH = ctx.lh(M.titleSize);
    const descH = ctx.lh(T.small);
    prim.text(slide, { x: textX, y: cy - (titleH + descH) / 2, w: textW, h: titleH }, item.title, { fontSize: M.titleSize, bold: true, valign: 'middle', name: 'timeline-title' });
    prim.text(slide, { x: textX, y: cy - (titleH + descH) / 2 + titleH, w: textW, h: descH }, item.desc, { tone: 'ink2', fontSize: T.small, valign: 'middle', name: 'timeline-desc' });
  }
}

async function staircase(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const S = theme.blocks.staircase;
  const n = data.items.length;
  const cols = stepBoxes(box, n, S.gap);
  const maxH = box.h - S.statusH;
  const minH = maxH * S.minFrac;
  for (const [i, item] of data.items.entries()) {
    const t = n === 1 ? 1 : i / (n - 1);
    const h = minH + (maxH - minH) * t;
    const c = { x: cols[i].x, y: box.y + maxH - h, w: cols[i].w, h };
    const risk = item.tone === 'risk';
    const transparency = Math.round(S.maxTransparency - (S.maxTransparency - S.minTransparency) * t);
    const textTone = risk ? 'risk' : S.textTone;
    if (risk) {
      slide.addShape(ctx.pres.shapes.ROUNDED_RECTANGLE, {
        x: c.x, y: c.y, w: c.w, h: c.h, rectRadius: theme.shape.radius,
        line: { color: palette.scheme('risk'), width: theme.shape.lineW, dashType: 'dash' },
        objectName: ctx.naming.next('stair-excluded'),
      });
    } else {
      prim.card(slide, c, { tone: data.tone || 'accent', transparency, withShadow: false, name: 'stair' });
    }
    const inner = { x: c.x + S.pad, w: c.w - 2 * S.pad };
    let y = c.y + S.pad;
    const levelH = ctx.lh(S.levelSize);
    const titleH = ctx.lh(S.titleSize);
    prim.text(slide, { ...inner, y, h: levelH }, item.level, { tone: textTone, fontSize: S.levelSize, bold: true, name: 'stair-level' });
    y += levelH;
    prim.text(slide, { ...inner, y, h: titleH }, item.title, { tone: textTone, fontSize: S.titleSize, bold: true, name: 'stair-title' });
    y += titleH;
    prim.text(slide, { ...inner, y, h: c.y + c.h - S.pad - y }, item.desc, { tone: textTone, fontSize: S.descSize, name: 'stair-desc' });
    prim.text(slide, { x: c.x, y: box.y + maxH, w: c.w, h: S.statusH }, item.status, {
      tone: risk ? 'risk' : 'muted', fontSize: theme.type.small, bold: true, align: 'center', valign: 'middle', name: 'stair-status',
    });
  }
}

module.exports = { steps, itemList, timeline, staircase };
