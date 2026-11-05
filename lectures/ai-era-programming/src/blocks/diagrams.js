'use strict';
/** Diagram blocks: chain (connected nodes), lanes (parallel timelines), columns, table. */

/** Connected nodes in one row, e.g. HMI → variable → PLC → I/O → device. */
async function chain(ctx, box, data) {
  const { slide, prim, theme } = ctx;
  const C = theme.blocks.chain;
  const T = theme.type;
  prim.card(slide, box, { name: 'chain-card' });
  const n = data.items.length;
  const cellW = (box.w - 2 * C.pad) / n;
  const titleH = ctx.lh(C.titleSize);
  const subH = ctx.lh(C.subSize);
  const spanH = data.span ? theme.shape.chipH + C.spanGap : 0;
  const groupH = C.node + C.itemGap + titleH + subH + spanH;
  const top = box.y + (box.h - groupH) / 2;
  const cy = top + C.node / 2;

  for (const [i, item] of data.items.entries()) {
    const cx = box.x + C.pad + cellW * (i + 0.5);
    await prim.iconCircle(slide, { x: cx - C.node / 2, y: top, d: C.node, icon: item.icon, tone: data.tone || 'accent', variant: 'solid', alt: item.title });
    const ty = top + C.node + C.itemGap;
    prim.text(slide, { x: cx - cellW / 2, y: ty, w: cellW, h: titleH }, item.title, { fontSize: C.titleSize, bold: true, align: 'center', name: 'chain-title' });
    prim.text(slide, { x: cx - cellW / 2, y: ty + titleH, w: cellW, h: subH }, item.sub, {
      tone: 'muted', fontSize: C.subSize, align: 'center', name: 'chain-sub',
    });
    if (i < n - 1) {
      const x0 = cx + C.node / 2 + C.arrowPad;
      prim.arrow(slide, { x: x0, y: cy, w: cellW - C.node - 2 * C.arrowPad, tone: 'muted', name: 'chain-arrow' });
    }
  }
  if (data.span) {
    const first = box.x + C.pad + cellW / 2;
    const last = box.x + C.pad + cellW * (n - 0.5);
    prim.pill(slide, {
      x: first - C.node / 2, y: top + groupH - theme.shape.chipH, w: last - first + C.node, label: data.span.label,
      tone: data.span.tone || 'ink', fontSize: T.small, name: 'chain-span',
    });
  }
}

/** Parallel horizontal timelines that share the same milestone columns. */
async function lanes(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const L = theme.blocks.lanes;
  const n = data.lanes.length;
  const laneH = (box.h - (n - 1) * theme.shape.listGap) / n;
  for (const [li, lane] of data.lanes.entries()) {
    const r = { x: box.x, y: box.y + li * (laneH + theme.shape.listGap), w: box.w, h: laneH };
    const tone = lane.tone || 'accent';
    prim.card(slide, r, { name: 'lane' });
    prim.text(slide, { x: r.x + L.pad, y: r.y, w: L.labelW - L.pad, h: r.h }, lane.label, { fontSize: L.labelSize, bold: true, valign: 'middle', name: 'lane-label' });

    const axisX = r.x + L.labelW;
    const axisW = r.x + r.w - L.pad - axisX;
    const cy = r.y + r.h / 2;
    const m = lane.items.length;
    const step = axisW / m;
    prim.rule(slide, { x: axisX + step / 2, y: cy, w: step * (m - 1), tone, transparency: theme.tint.rule, name: 'lane-axis' });
    const whenH = ctx.lh(L.whenSize);
    const titleH = ctx.lh(L.titleSize, 2);
    for (const [i, item] of lane.items.entries()) {
      const x = axisX + step * i;
      const last = i === m - 1;
      slide.addShape(ctx.pres.shapes.OVAL, {
        x: x + step / 2 - L.dot / 2, y: cy - L.dot / 2, w: L.dot, h: L.dot,
        fill: { color: palette.scheme(last ? tone : 'paper') }, line: { color: palette.scheme(tone), width: theme.shape.lineW },
        objectName: ctx.naming.next('lane-dot'),
      });
      prim.text(slide, { x, y: cy - L.dot / 2 - L.labelGap - whenH, w: step, h: whenH }, item.when, {
        tone, fontSize: L.whenSize, bold: true, align: 'center', valign: 'bottom', name: 'lane-when',
      });
      prim.text(slide, { x: x + L.itemPad, y: cy + L.dot / 2 + L.labelGap, w: step - 2 * L.itemPad, h: titleH }, item.title, {
        fontSize: L.titleSize, bold: last, align: 'center', name: 'lane-title',
      });
    }
  }
}

/** Side-by-side columns, each with a toned header and a bullet list. */
async function columns(ctx, box, data) {
  const { slide, prim, theme, palette } = ctx;
  const C = theme.blocks.columns;
  const n = data.items.length;
  const w = (box.w - (n - 1) * theme.grid.gap) / n;
  const d = theme.shape.iconCircle;
  for (const [i, item] of data.items.entries()) {
    const c = { x: box.x + i * (w + theme.grid.gap), y: box.y, w, h: box.h };
    const inner = { x: c.x + C.pad, w: c.w - 2 * C.pad };
    prim.card(slide, c, { name: 'column' });
    let y = c.y + C.pad;
    await prim.iconCircle(slide, { x: inner.x, y, d, icon: item.icon, tone: item.tone, alt: item.title });
    prim.text(slide, { x: inner.x + d + C.pad / 2, y, w: inner.w - d - C.pad / 2, h: d }, item.title, {
      tone: item.tone, fontSize: C.titleSize, bold: true, valign: 'middle', name: 'column-title',
    });
    y += d + C.pad / 2;
    prim.rule(slide, { x: inner.x, y, w: inner.w, tone: 'muted', width: theme.shape.hairline, transparency: theme.tint.rule, name: 'column-rule' });
    y += C.pad / 2;
    const runs = item.bullets.map((b, j) => ({
      text: b,
      options: {
        bullet: true, fontSize: C.bulletSize, color: palette.scheme('ink'), paraSpaceAfter: C.bulletSpace,
        ...(j < item.bullets.length - 1 ? { breakLine: true } : {}),
      },
    }));
    prim.text(slide, { ...inner, y, h: c.y + c.h - C.pad - y }, runs, { name: 'column-bullets' });
  }
}

/** Native PowerPoint table with a dark header row. */
async function table(ctx, box, data) {
  const { slide, theme, palette } = ctx;
  const TB = theme.blocks.table;
  const fracSum = data.colFrac.reduce((a, b) => a + b, 0);
  const colW = data.colFrac.map((f) => (box.w * f) / fracSum);
  const bodyH = (box.h - TB.headerH) / data.rows.length;
  const header = data.header.map((t) => ({
    text: t,
    options: { bold: true, fontSize: TB.headerSize, color: palette.scheme('paper'), fill: { color: palette.scheme('ink') } },
  }));
  const body = data.rows.map((row) => row.map((t, ci) => {
    const emph = ci === data.emphasizeCol;
    return {
      text: t,
      options: {
        fontSize: TB.fontSize, bold: emph || ci === 0,
        color: palette.scheme(emph ? 'accent' : ci === 0 ? 'ink' : 'ink2'),
        fill: { color: palette.scheme('paper') },
      },
    };
  }));
  slide.addTable([header, ...body], {
    x: box.x, y: box.y, w: box.w, colW,
    rowH: [TB.headerH, ...data.rows.map(() => bodyH)],
    valign: 'middle', margin: [0, TB.padX, 0, TB.padX],
    border: { type: 'solid', pt: theme.shape.hairline, color: palette.hex('muted') },
    objectName: ctx.naming.next('table'),
  });
}

module.exports = { chain, lanes, columns, table };
