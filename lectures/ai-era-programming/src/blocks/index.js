'use strict';
/** Block registry: content `"type"` → async render(ctx, box, data). Add new block types here. */
const basic = require('./basic');
const cards = require('./cards');
const flows = require('./flows');
const compare = require('./compare');

const registry = Object.freeze({
  chips: basic.chips,
  presenter: basic.presenter,
  code: basic.code,
  agenda: cards.agenda,
  profile: cards.profile,
  stats: cards.stats,
  cards: cards.cards,
  steps: flows.steps,
  itemList: flows.itemList,
  timeline: flows.timeline,
  staircase: flows.staircase,
  quoteCard: compare.quoteCard,
  compareFlow: compare.compareFlow,
  compareStatements: compare.compareStatements,
  shiftTable: compare.shiftTable,
  statements: compare.statements,
  contact: compare.contact,
});

module.exports = { registry };
