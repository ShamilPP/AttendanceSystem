const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
const timezone = require('dayjs/plugin/timezone');
const isoWeek = require('dayjs/plugin/isoWeek');
const customParseFormat = require('dayjs/plugin/customParseFormat');

dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.extend(isoWeek);
dayjs.extend(customParseFormat);

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MONTH_RE = /^\d{4}-\d{2}$/;
const HM_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

function isValidDateStr(s) {
  return typeof s === 'string' && DATE_RE.test(s) && dayjs(s, 'YYYY-MM-DD', true).isValid();
}

function isValidMonthStr(s) {
  return typeof s === 'string' && MONTH_RE.test(s) && dayjs(`${s}-01`, 'YYYY-MM-DD', true).isValid();
}

function isValidHm(s) {
  return typeof s === 'string' && HM_RE.test(s);
}

/** Today's calendar date (YYYY-MM-DD) in the office timezone. */
function todayInTz(tz) {
  return dayjs().tz(tz).format('YYYY-MM-DD');
}

/** dayjs instant for a calendar date + HH:mm interpreted in the office timezone. */
function atTime(dateStr, hm, tz) {
  return dayjs.tz(`${dateStr} ${hm}`, 'YYYY-MM-DD HH:mm', tz);
}

/** Is the given calendar date a Mon-Fri working day? */
function isWorkingDay(dateStr) {
  const d = dayjs(dateStr, 'YYYY-MM-DD', true).day();
  return d >= 1 && d <= 5;
}

/** Count Mon-Fri days between two YYYY-MM-DD dates inclusive. */
function workingDaysBetween(fromStr, toStr) {
  if (!fromStr || !toStr || fromStr > toStr) return 0;
  let count = 0;
  let cur = dayjs(fromStr, 'YYYY-MM-DD', true);
  const end = dayjs(toStr, 'YYYY-MM-DD', true);
  while (cur.isBefore(end) || cur.isSame(end, 'day')) {
    const d = cur.day();
    if (d >= 1 && d <= 5) count += 1;
    cur = cur.add(1, 'day');
  }
  return count;
}

/** List of YYYY-MM-DD strings between two dates inclusive. */
function listDays(fromStr, toStr) {
  const days = [];
  if (!fromStr || !toStr || fromStr > toStr) return days;
  let cur = dayjs(fromStr, 'YYYY-MM-DD', true);
  const end = dayjs(toStr, 'YYYY-MM-DD', true);
  while (cur.isBefore(end) || cur.isSame(end, 'day')) {
    days.push(cur.format('YYYY-MM-DD'));
    cur = cur.add(1, 'day');
  }
  return days;
}

/** [start, end] YYYY-MM-DD strings for a YYYY-MM month. */
function monthRange(monthStr) {
  const start = dayjs(`${monthStr}-01`, 'YYYY-MM-DD', true);
  return [start.format('YYYY-MM-DD'), start.endOf('month').format('YYYY-MM-DD')];
}

/** Parse an ISO timestamp into a Date, or null if invalid. */
function parseIso(value) {
  if (value === null || value === undefined || value === '') return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Format an instant as HH:mm in the office timezone ('' when null). */
function formatHmInTz(date, tz) {
  if (!date) return '';
  return dayjs(date).tz(tz).format('HH:mm');
}

module.exports = {
  dayjs,
  isValidDateStr,
  isValidMonthStr,
  isValidHm,
  todayInTz,
  atTime,
  isWorkingDay,
  workingDaysBetween,
  listDays,
  monthRange,
  parseIso,
  formatHmInTz,
};
