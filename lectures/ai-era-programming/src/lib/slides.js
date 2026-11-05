'use strict';
/** Turns one content slide into a pptx slide: placeholders → blocks → band → notes. */
const { formatClock } = require('./timing');

function formatDuration(minutes, units) {
  const total = Math.round(minutes * 60);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return [m ? `${m}${units.min}` : '', s ? `${s}${units.sec}` : ''].filter(Boolean).join(' ');
}

function notesFor(data, schedule, meta) {
  const t = schedule.slide(data.id);
  const header = `[${meta.notesTimingLabel}] ${formatClock(t.start)} – ${formatClock(t.end)} (${formatDuration(t.minutes, meta.durationUnits)})`;
  return data.notes ? `${header}\n\n${data.notes}` : header;
}

function createSlideRenderer(env) {
  const { pres, theme, grid, prim, registry, layouts, schedule, content } = env;
  const sectionTitles = Object.fromEntries(content.sections.map((s) => [s.id, s.title]));
  const addedSections = new Set();
  const lh = (pt, lines = 1) => (pt * theme.measure.lineSpacing * lines) / 72;

  function areaFor(data) {
    if (data.layout === layouts.DARK) return { top: theme.dark.contentTop, bottom: theme.dark.contentBottom };
    return grid.contentArea({ hasBand: Boolean(data.band), hasLead: Boolean(data.lead) });
  }

  return async function renderSlide(data) {
    const sectionTitle = sectionTitles[data.section];
    if (!addedSections.has(data.section)) {
      pres.addSection({ title: sectionTitle });
      addedSections.add(data.section);
    }
    const slide = pres.addSlide({ masterName: data.layout, sectionTitle });
    slide._deckSlideId = data.id;

    if (data.kicker) {
      const k = theme.grid.kicker;
      const ky = data.layout === layouts.DARK ? theme.dark.kicker.y : k.y;
      slide.addShape(pres.shapes.OVAL, {
        x: theme.grid.marginX, y: ky + (k.h - k.dot) / 2, w: k.dot, h: k.dot,
        fill: { color: env.palette.scheme('accent') }, line: { type: 'none' }, objectName: env.naming.next('kicker-dot'),
      });
      slide.addText(data.kicker, { placeholder: 'kicker', bullet: false });
    }
    slide.addText(data.title, { placeholder: 'title', bullet: false });
    if (data.lead) slide.addText(data.lead, { placeholder: 'lead', bullet: false });

    const surface = data.layout === layouts.DARK ? 'dark' : 'light';
    const ctx = {
      ...env,
      slide,
      slideId: data.id,
      surface,
      ink: surface === 'dark' ? { text: 'paper', sub: 'paper2', muted: 'muted' } : { text: 'ink', sub: 'ink2', muted: 'muted' },
      sectionTitles,
      lh,
    };
    const area = areaFor(data);
    for (const block of data.blocks || []) {
      await registry[block.type](ctx, grid.region(block.region, area), block);
    }
    if (data.band) prim.band(slide, grid.bandBox(), data.band);
    slide.addNotes(notesFor(data, schedule, content.meta));
    return slide;
  };
}

module.exports = { createSlideRenderer, formatDuration };
