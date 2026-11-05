'use strict';
/**
 * Slide layouts (pptxgenjs "masters"). Two frames:
 *   CONTENT — light background, kicker / title / lead placeholders, footer, slide number
 *   DARK    — dark background for the cover and closing
 * Positions come from theme.grid / theme.dark, copy (footer) from content meta.
 */
const LAYOUTS = Object.freeze({ CONTENT: 'CONTENT', DARK: 'DARK' });

function placeholder(name, type, options) {
  return { placeholder: { options: { name, type, margin: 0, bullet: false, ...options }, text: '' } };
}

function defineLayouts({ pres, theme, palette, meta }) {
  const { page, grid, dark, type } = theme;
  const innerW = page.w - 2 * grid.marginX;
  const kicker = grid.kicker;

  const kickerDot = (y) => ({
    text: {
      text: '',
      options: {
        shape: pres.shapes.OVAL,
        x: grid.marginX, y: y + (kicker.h - kicker.dot) / 2, w: kicker.dot, h: kicker.dot,
        fill: { color: palette.scheme('accent') }, line: { type: 'none' },
      },
    },
  });

  const kickerPh = (y) => placeholder('kicker', 'body', {
    x: grid.marginX + kicker.indent, y, w: innerW - kicker.indent, h: kicker.h,
    fontSize: type.kicker, bold: true, charSpacing: type.kickerCharSpacing,
    color: palette.scheme('accent'), valign: 'middle',
  });

  pres.defineSlideMaster({
    title: LAYOUTS.CONTENT,
    background: { color: palette.scheme('paper2') },
    objects: [
      kickerDot(kicker.y),
      kickerPh(kicker.y),
      placeholder('title', 'title', {
        x: grid.marginX, y: grid.title.y, w: innerW, h: grid.title.h,
        fontSize: type.title, bold: true, color: palette.scheme('ink'), valign: 'middle', align: 'left',
      }),
      placeholder('lead', 'body', {
        x: grid.marginX, y: grid.lead.y, w: innerW, h: grid.lead.h,
        fontSize: type.lead, color: palette.scheme('ink2'), valign: 'top',
      }),
      {
        text: {
          text: meta.footer,
          options: {
            x: grid.marginX, y: grid.footer.y, w: innerW / 2, h: grid.footer.h,
            fontSize: type.footer, color: palette.scheme('muted'), margin: 0, valign: 'middle',
          },
        },
      },
    ],
    slideNumber: {
      x: page.w - grid.marginX - 1, y: grid.footer.y, w: 1, h: grid.footer.h,
      fontSize: type.footer, color: palette.scheme('muted'), align: 'right', margin: 0,
    },
  });

  pres.defineSlideMaster({
    title: LAYOUTS.DARK,
    background: { color: palette.scheme('ink') },
    objects: [
      kickerDot(dark.kicker.y),
      kickerPh(dark.kicker.y),
      placeholder('title', 'title', {
        x: grid.marginX, y: dark.title.y, w: dark.titleColW, h: dark.title.h,
        fontSize: type.darkTitle, bold: true, color: palette.scheme('paper'), valign: 'middle', align: 'left',
      }),
      placeholder('lead', 'body', {
        x: grid.marginX, y: dark.lead.y, w: dark.titleColW, h: dark.lead.h,
        fontSize: type.darkLead, color: palette.scheme('paper2'), valign: 'top',
      }),
    ],
  });

  return LAYOUTS;
}

module.exports = { defineLayouts, LAYOUTS };
