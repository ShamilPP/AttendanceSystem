const mongoose = require('mongoose');
const Attendance = require('../models/Attendance');
const User = require('../models/User');
const OfficeSettings = require('../models/OfficeSettings');
const { USER_POPULATE } = require('./authController');
const {
  ApiError,
  ok,
  asyncHandler,
  parsePaging,
  buildPagination,
} = require('../utils/respond');
const {
  todayInTz,
  isValidDateStr,
  isValidMonthStr,
  monthRange,
  workingDaysBetween,
  parseIso,
  dayjs,
} = require('../utils/time');
const { decryptQrPayload, isQrPayloadFresh } = require('../utils/qr');
const { haversineMeters } = require('../utils/geo');
const {
  PRESENT_STATUSES,
  recomputeAttendance,
  deriveWorkedStatus,
  liveStatusOf,
  hasOpenBreak,
  ATTENDANCE_EMPLOYEE_POPULATE,
} = require('../utils/attendanceCalc');
const { resolveEmployee } = require('../utils/employeeLookup');

const SCAN_ACTIONS = ['CHECK_IN', 'CHECK_OUT', 'BREAK_START', 'BREAK_END'];
const ATT_STATUSES = ['PRESENT', 'LATE', 'ABSENT', 'ON_LEAVE', 'HALF_DAY'];

async function populated(att) {
  return att.populate(ATTENDANCE_EMPLOYEE_POPULATE);
}

// ---------------------------------------------------------------- employee

// POST /attendance/scan
const scan = asyncHandler(async (req, res) => {
  const { qrData, action } = req.body || {};
  const latitude = Number(req.body ? req.body.latitude : undefined);
  const longitude = Number(req.body ? req.body.longitude : undefined);

  const errors = [];
  if (!qrData || typeof qrData !== 'string') {
    errors.push({ field: 'qrData', message: 'qrData is required' });
  }
  if (!SCAN_ACTIONS.includes(action)) {
    errors.push({ field: 'action', message: `action must be one of ${SCAN_ACTIONS.join(', ')}` });
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    errors.push({ field: 'latitude', message: 'A valid latitude is required' });
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    errors.push({ field: 'longitude', message: 'A valid longitude is required' });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const settings = await OfficeSettings.getSingleton();

  // 1) QR must decrypt and be fresh
  const payload = decryptQrPayload(qrData);
  if (!isQrPayloadFresh(payload, settings.qrRefreshSeconds)) {
    throw new ApiError(403, 'Invalid or expired QR code');
  }

  // 2) Geofence
  const distance = haversineMeters(latitude, longitude, settings.latitude, settings.longitude);
  if (distance > settings.radiusMeters) {
    throw new ApiError(
      403,
      `You are outside the allowed office area (${Math.round(distance)}m away, limit ${settings.radiusMeters}m)`
    );
  }

  // 3) State machine
  const now = new Date();
  const date = todayInTz(settings.timezone);
  const location = { latitude, longitude };
  let att = await Attendance.findOne({ employee: req.user._id, date });
  let message;

  switch (action) {
    case 'CHECK_IN': {
      if (att && att.checkIn) throw new ApiError(409, 'You have already checked in today');
      if (!att) att = new Attendance({ employee: req.user._id, date });
      att.checkIn = now;
      att.checkInLocation = location;
      recomputeAttendance(att, settings, now);
      att.status = att.isLate ? 'LATE' : 'PRESENT';
      message = att.isLate ? 'Checked in successfully (marked late)' : 'Checked in successfully';
      break;
    }
    case 'CHECK_OUT': {
      if (!att || !att.checkIn) throw new ApiError(400, 'You must check in before checking out');
      if (att.checkOut) throw new ApiError(409, 'You have already checked out today');
      const openBreak = att.breaks.find((b) => b.start && !b.end);
      if (openBreak) openBreak.end = now; // auto-close open break
      att.checkOut = now;
      att.checkOutLocation = location;
      recomputeAttendance(att, settings, now);
      deriveWorkedStatus(att);
      message = att.isEarlyOut
        ? 'Checked out successfully (early check-out)'
        : 'Checked out successfully';
      break;
    }
    case 'BREAK_START': {
      if (!att || !att.checkIn) throw new ApiError(400, 'You must check in before starting a break');
      if (att.checkOut) throw new ApiError(409, 'You have already checked out today');
      if (hasOpenBreak(att)) throw new ApiError(409, 'A break is already in progress');
      att.breaks.push({ start: now, end: null });
      recomputeAttendance(att, settings, now);
      message = 'Break started';
      break;
    }
    case 'BREAK_END': {
      if (!att || !att.checkIn) throw new ApiError(400, 'You must check in before ending a break');
      if (att.checkOut) throw new ApiError(409, 'You have already checked out today');
      const openBreak = att.breaks.find((b) => b.start && !b.end);
      if (!openBreak) throw new ApiError(400, 'No break is currently in progress');
      openBreak.end = now;
      recomputeAttendance(att, settings, now);
      message = 'Break ended';
      break;
    }
    default:
      throw new ApiError(400, 'Unknown action');
  }

  await att.save();
  await populated(att);
  ok(res, { attendance: att, message });
});

// GET /attendance/today
const today = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  const date = todayInTz(settings.timezone);
  const att = await Attendance.findOne({ employee: req.user._id, date }).populate(
    ATTENDANCE_EMPLOYEE_POPULATE
  );
  ok(res, att || null);
});

// GET /attendance/history
const history = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const { page, limit, skip } = parsePaging(req.query);

  const errors = [];
  if (from && !isValidDateStr(from)) errors.push({ field: 'from', message: 'Use YYYY-MM-DD' });
  if (to && !isValidDateStr(to)) errors.push({ field: 'to', message: 'Use YYYY-MM-DD' });
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const filter = { employee: req.user._id };
  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = from;
    if (to) filter.date.$lte = to;
  }

  const [total, records] = await Promise.all([
    Attendance.countDocuments(filter),
    Attendance.find(filter)
      .populate(ATTENDANCE_EMPLOYEE_POPULATE)
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit),
  ]);

  ok(res, records, { pagination: buildPagination(page, limit, total) });
});

// GET /attendance/summary?month=YYYY-MM
const summary = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  const todayStr = todayInTz(settings.timezone);
  const month = req.query.month || todayStr.slice(0, 7);
  if (!isValidMonthStr(month)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'month', message: 'Use YYYY-MM' },
    ]);
  }

  const [monthStart, monthEnd] = monthRange(month);
  const effectiveEnd = monthEnd < todayStr ? monthEnd : todayStr;
  const workingDays = monthStart > effectiveEnd ? 0 : workingDaysBetween(monthStart, effectiveEnd);

  const records = await Attendance.find({
    employee: req.user._id,
    date: { $gte: monthStart, $lte: monthEnd },
  })
    .populate(ATTENDANCE_EMPLOYEE_POPULATE)
    .sort({ date: 1 });

  let presentDays = 0;
  let lateDays = 0;
  let leaveDays = 0;
  let halfDays = 0;
  let earlyOutDays = 0;
  let totalWorkMinutes = 0;
  let totalBreakMinutes = 0;

  for (const r of records) {
    if (PRESENT_STATUSES.includes(r.status)) presentDays += 1;
    if (r.status === 'ON_LEAVE') leaveDays += 1;
    if (r.status === 'HALF_DAY') halfDays += 1;
    if (r.isLate) lateDays += 1;
    if (r.isEarlyOut) earlyOutDays += 1;
    totalWorkMinutes += r.workMinutes || 0;
    totalBreakMinutes += r.breakMinutes || 0;
  }

  const absentDays = Math.max(0, workingDays - presentDays - leaveDays);
  const averageWorkMinutes = presentDays > 0 ? Math.round(totalWorkMinutes / presentDays) : 0;

  ok(res, {
    month,
    workingDays,
    presentDays,
    lateDays,
    absentDays,
    leaveDays,
    halfDays,
    totalWorkMinutes,
    totalBreakMinutes,
    averageWorkMinutes,
    earlyOutDays,
    records,
  });
});

// ---------------------------------------------------------------- admin

// GET /attendance/live
const live = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  const date = todayInTz(settings.timezone);

  const employeeFilter = { role: 'employee', isActive: true };
  if (req.query.departmentId) {
    if (!mongoose.isValidObjectId(req.query.departmentId)) {
      throw new ApiError(400, 'Validation failed', [
        { field: 'departmentId', message: 'Must be a valid id' },
      ]);
    }
    employeeFilter.department = req.query.departmentId;
  }

  const employees = await User.find(employeeFilter).populate(USER_POPULATE).sort({ employeeId: 1 });
  const attendanceDocs = await Attendance.find({
    date,
    employee: { $in: employees.map((e) => e._id) },
  }).populate(ATTENDANCE_EMPLOYEE_POPULATE);

  const byEmployee = new Map(attendanceDocs.map((a) => [String(a.employee._id), a]));

  let present = 0;
  let late = 0;
  let onLeave = 0;
  let checkedOut = 0;
  let onBreak = 0;

  const records = employees.map((employee) => {
    const att = byEmployee.get(String(employee._id)) || null;
    const liveStatus = liveStatusOf(att);
    if (att) {
      if (PRESENT_STATUSES.includes(att.status)) present += 1;
      if (att.isLate) late += 1;
      if (att.status === 'ON_LEAVE') onLeave += 1;
    }
    if (liveStatus === 'CHECKED_OUT') checkedOut += 1;
    if (liveStatus === 'ON_BREAK') onBreak += 1;
    return { employee, attendance: att, liveStatus };
  });

  const total = employees.length;
  const absent = Math.max(0, total - present - onLeave);

  ok(res, {
    date,
    summary: { total, present, late, absent, onLeave, checkedOut, onBreak },
    records,
  });
});

// GET /attendance/logs
const logs = asyncHandler(async (req, res) => {
  const { employeeId, from, to, status } = req.query;
  const { page, limit, skip } = parsePaging(req.query);

  const errors = [];
  if (from && !isValidDateStr(from)) errors.push({ field: 'from', message: 'Use YYYY-MM-DD' });
  if (to && !isValidDateStr(to)) errors.push({ field: 'to', message: 'Use YYYY-MM-DD' });
  if (status && !ATT_STATUSES.includes(status)) {
    errors.push({ field: 'status', message: `Must be one of ${ATT_STATUSES.join(', ')}` });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const filter = {};
  if (employeeId) {
    const employee = await resolveEmployee(employeeId);
    if (!employee) throw new ApiError(404, 'Employee not found');
    filter.employee = employee._id;
  }
  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = from;
    if (to) filter.date.$lte = to;
  }
  if (status) filter.status = status;

  const [total, records] = await Promise.all([
    Attendance.countDocuments(filter),
    Attendance.find(filter)
      .populate(ATTENDANCE_EMPLOYEE_POPULATE)
      .sort({ date: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
  ]);

  ok(res, records, { pagination: buildPagination(page, limit, total) });
});

function parseBreaksInput(rawBreaks, errors) {
  if (!Array.isArray(rawBreaks)) {
    errors.push({ field: 'breaks', message: 'Must be an array of { start, end } objects' });
    return [];
  }
  const parsed = [];
  for (const b of rawBreaks) {
    const start = parseIso(b && b.start);
    if (!start) {
      errors.push({ field: 'breaks', message: 'Each break needs a valid ISO start time' });
      continue;
    }
    let end = null;
    if (b.end !== null && b.end !== undefined && b.end !== '') {
      end = parseIso(b.end);
      if (!end) {
        errors.push({ field: 'breaks', message: 'Break end must be a valid ISO time or null' });
        continue;
      }
      if (end < start) {
        errors.push({ field: 'breaks', message: 'Break end must be after its start' });
        continue;
      }
    }
    parsed.push({ start, end });
  }
  return parsed;
}

// PUT /attendance/:id/correct
const correct = asyncHandler(async (req, res) => {
  const body = req.body || {};
  const { note, status } = body;
  const errors = [];
  if (!note || !String(note).trim()) {
    errors.push({ field: 'note', message: 'A correction note is required' });
  }
  if (status !== undefined && !ATT_STATUSES.includes(status)) {
    errors.push({ field: 'status', message: `Must be one of ${ATT_STATUSES.join(', ')}` });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const att = await Attendance.findById(req.params.id);
  if (!att) throw new ApiError(404, 'Attendance record not found');

  if ('checkIn' in body) {
    if (body.checkIn === null || body.checkIn === '') {
      att.checkIn = null;
    } else {
      const d = parseIso(body.checkIn);
      if (!d) {
        throw new ApiError(400, 'Validation failed', [
          { field: 'checkIn', message: 'Must be a valid ISO timestamp or null' },
        ]);
      }
      att.checkIn = d;
    }
  }
  if ('checkOut' in body) {
    if (body.checkOut === null || body.checkOut === '') {
      att.checkOut = null;
    } else {
      const d = parseIso(body.checkOut);
      if (!d) {
        throw new ApiError(400, 'Validation failed', [
          { field: 'checkOut', message: 'Must be a valid ISO timestamp or null' },
        ]);
      }
      att.checkOut = d;
    }
  }
  if ('breaks' in body) {
    const breakErrors = [];
    const parsed = parseBreaksInput(body.breaks, breakErrors);
    if (breakErrors.length) throw new ApiError(400, 'Validation failed', breakErrors);
    att.breaks = parsed;
  }
  if (att.checkIn && att.checkOut && att.checkOut < att.checkIn) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'checkOut', message: 'checkOut must be after checkIn' },
    ]);
  }

  const settings = await OfficeSettings.getSingleton();
  recomputeAttendance(att, settings);
  if (status !== undefined) {
    att.status = status;
  } else {
    deriveWorkedStatus(att);
  }

  att.correction = {
    correctedBy: req.user._id,
    note: String(note).trim(),
    correctedAt: new Date(),
  };

  await att.save();
  await populated(att);
  ok(res, att);
});

// POST /attendance/manual
const manual = asyncHandler(async (req, res) => {
  const { employeeId, date, checkIn, checkOut, status, note } = req.body || {};

  const errors = [];
  if (!employeeId) errors.push({ field: 'employeeId', message: 'employeeId is required' });
  if (!date || !isValidDateStr(date)) errors.push({ field: 'date', message: 'Use YYYY-MM-DD' });
  if (!note || !String(note).trim()) errors.push({ field: 'note', message: 'A note is required' });
  if (status !== undefined && !ATT_STATUSES.includes(status)) {
    errors.push({ field: 'status', message: `Must be one of ${ATT_STATUSES.join(', ')}` });
  }
  let checkInDate = null;
  if (checkIn !== undefined && checkIn !== null && checkIn !== '') {
    checkInDate = parseIso(checkIn);
    if (!checkInDate) errors.push({ field: 'checkIn', message: 'Must be a valid ISO timestamp' });
  }
  let checkOutDate = null;
  if (checkOut !== undefined && checkOut !== null && checkOut !== '') {
    checkOutDate = parseIso(checkOut);
    if (!checkOutDate) errors.push({ field: 'checkOut', message: 'Must be a valid ISO timestamp' });
  }
  if (!checkInDate && status === undefined) {
    errors.push({ field: 'status', message: 'Provide a status or a checkIn time' });
  }
  if (checkInDate && checkOutDate && checkOutDate < checkInDate) {
    errors.push({ field: 'checkOut', message: 'checkOut must be after checkIn' });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const employee = await resolveEmployee(employeeId);
  if (!employee) throw new ApiError(404, 'Employee not found');

  const existing = await Attendance.findOne({ employee: employee._id, date });
  if (existing) {
    throw new ApiError(409, 'An attendance record already exists for this employee on this date');
  }

  const settings = await OfficeSettings.getSingleton();
  const att = new Attendance({
    employee: employee._id,
    date,
    checkIn: checkInDate,
    checkOut: checkOutDate,
  });
  recomputeAttendance(att, settings);
  if (status !== undefined) {
    att.status = status;
  } else {
    deriveWorkedStatus(att);
  }
  att.correction = {
    correctedBy: req.user._id,
    note: String(note).trim(),
    correctedAt: new Date(),
  };

  await att.save();
  await populated(att);
  ok(res, att, { status: 201 });
});

// GET /attendance/missing-checkouts?date=
const missingCheckouts = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  let { date } = req.query;
  if (date) {
    if (!isValidDateStr(date)) {
      throw new ApiError(400, 'Validation failed', [{ field: 'date', message: 'Use YYYY-MM-DD' }]);
    }
  } else {
    date = dayjs(todayInTz(settings.timezone), 'YYYY-MM-DD', true)
      .subtract(1, 'day')
      .format('YYYY-MM-DD');
  }

  const records = await Attendance.find({
    date,
    checkIn: { $ne: null },
    checkOut: null,
  })
    .populate(ATTENDANCE_EMPLOYEE_POPULATE)
    .sort({ checkIn: 1 });

  ok(res, records);
});

// PUT /attendance/:id/resolve-checkout
const resolveCheckout = asyncHandler(async (req, res) => {
  const { checkOut, note } = req.body || {};
  const errors = [];
  const checkOutDate = parseIso(checkOut);
  if (!checkOutDate) errors.push({ field: 'checkOut', message: 'A valid ISO checkOut is required' });
  if (!note || !String(note).trim()) errors.push({ field: 'note', message: 'A note is required' });
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const att = await Attendance.findById(req.params.id);
  if (!att) throw new ApiError(404, 'Attendance record not found');
  if (!att.checkIn) throw new ApiError(400, 'This record has no check-in to resolve');
  if (att.checkOut) throw new ApiError(409, 'This record already has a check-out');
  if (checkOutDate < att.checkIn) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'checkOut', message: 'checkOut must be after checkIn' },
    ]);
  }

  const openBreak = att.breaks.find((b) => b.start && !b.end);
  if (openBreak) openBreak.end = checkOutDate;
  att.checkOut = checkOutDate;

  const settings = await OfficeSettings.getSingleton();
  recomputeAttendance(att, settings);
  deriveWorkedStatus(att);
  att.correction = {
    correctedBy: req.user._id,
    note: String(note).trim(),
    correctedAt: new Date(),
  };

  await att.save();
  await populated(att);
  ok(res, att);
});

module.exports = {
  scan,
  today,
  history,
  summary,
  live,
  logs,
  correct,
  manual,
  missingCheckouts,
  resolveCheckout,
};
