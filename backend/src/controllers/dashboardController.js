const Attendance = require('../models/Attendance');
const User = require('../models/User');
const OfficeSettings = require('../models/OfficeSettings');
const { ApiError, ok, asyncHandler } = require('../utils/respond');
const {
  todayInTz,
  isValidDateStr,
  workingDaysBetween,
  listDays,
  dayjs,
} = require('../utils/time');
const { PRESENT_STATUSES } = require('../utils/attendanceCalc');

function summarizeDay(records) {
  let present = 0;
  let late = 0;
  let onLeave = 0;
  let checkedOut = 0;
  let workMinutesSum = 0;
  let workedCount = 0;

  for (const r of records) {
    if (PRESENT_STATUSES.includes(r.status)) present += 1;
    if (r.isLate) late += 1;
    if (r.status === 'ON_LEAVE') onLeave += 1;
    if (r.checkOut) checkedOut += 1;
    if (r.checkIn) {
      workMinutesSum += r.workMinutes || 0;
      workedCount += 1;
    }
  }
  return { present, late, onLeave, checkedOut, workMinutesSum, workedCount };
}

// GET /dashboard/stats?date=
const stats = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  const date = req.query.date || todayInTz(settings.timezone);
  if (!isValidDateStr(date)) {
    throw new ApiError(400, 'Validation failed', [{ field: 'date', message: 'Use YYYY-MM-DD' }]);
  }

  const [totalEmployees, records] = await Promise.all([
    User.countDocuments({ role: 'employee', isActive: true }),
    Attendance.find({ date }),
  ]);

  const day = summarizeDay(records);
  const absent = Math.max(0, totalEmployees - day.present - day.onLeave);
  const averageWorkMinutes = day.workedCount > 0 ? Math.round(day.workMinutesSum / day.workedCount) : 0;
  const attendanceRate =
    totalEmployees > 0 ? Math.round((day.present / totalEmployees) * 100) : 0;

  ok(res, {
    totalEmployees,
    present: day.present,
    absent,
    late: day.late,
    onLeave: day.onLeave,
    checkedOut: day.checkedOut,
    averageWorkMinutes,
    attendanceRate,
  });
});

// GET /dashboard/trends?period=daily|weekly|monthly
const trends = asyncHandler(async (req, res) => {
  const period = req.query.period || 'daily';
  if (!['daily', 'weekly', 'monthly'].includes(period)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'period', message: 'Must be daily, weekly or monthly' },
    ]);
  }

  const settings = await OfficeSettings.getSingleton();
  const todayStr = todayInTz(settings.timezone);
  const today = dayjs(todayStr, 'YYYY-MM-DD', true);
  const totalEmployees = await User.countDocuments({ role: 'employee', isActive: true });

  let points = [];

  if (period === 'daily') {
    const fromStr = today.subtract(13, 'day').format('YYYY-MM-DD');
    const records = await Attendance.find({ date: { $gte: fromStr, $lte: todayStr } });
    const byDate = new Map();
    for (const r of records) {
      if (!byDate.has(r.date)) byDate.set(r.date, []);
      byDate.get(r.date).push(r);
    }
    points = listDays(fromStr, todayStr).map((dateStr) => {
      const day = summarizeDay(byDate.get(dateStr) || []);
      return {
        label: dateStr,
        present: day.present,
        late: day.late,
        absent: Math.max(0, totalEmployees - day.present - day.onLeave),
      };
    });
  } else {
    const buckets = [];
    if (period === 'weekly') {
      for (let i = 7; i >= 0; i -= 1) {
        const anchor = today.subtract(i, 'week');
        const start = anchor.isoWeekday(1);
        const end = anchor.isoWeekday(7);
        buckets.push({
          label: `${anchor.isoWeekYear()}-W${String(anchor.isoWeek()).padStart(2, '0')}`,
          from: start.format('YYYY-MM-DD'),
          to: end.format('YYYY-MM-DD'),
        });
      }
    } else {
      for (let i = 5; i >= 0; i -= 1) {
        const anchor = today.subtract(i, 'month');
        buckets.push({
          label: anchor.format('YYYY-MM'),
          from: anchor.startOf('month').format('YYYY-MM-DD'),
          to: anchor.endOf('month').format('YYYY-MM-DD'),
        });
      }
    }

    const rangeFrom = buckets[0].from;
    const records = await Attendance.find({ date: { $gte: rangeFrom, $lte: todayStr } });

    points = buckets.map((bucket) => {
      const effectiveTo = bucket.to < todayStr ? bucket.to : todayStr;
      const inBucket = records.filter((r) => r.date >= bucket.from && r.date <= bucket.to);
      let present = 0;
      let late = 0;
      let leave = 0;
      for (const r of inBucket) {
        if (PRESENT_STATUSES.includes(r.status)) present += 1;
        if (r.isLate) late += 1;
        if (r.status === 'ON_LEAVE') leave += 1;
      }
      const workingDays =
        bucket.from > effectiveTo ? 0 : workingDaysBetween(bucket.from, effectiveTo);
      const absent = Math.max(0, workingDays * totalEmployees - present - leave);
      return { label: bucket.label, present, late, absent };
    });
  }

  ok(res, { period, points });
});

module.exports = { stats, trends };
