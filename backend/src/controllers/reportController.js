const mongoose = require('mongoose');
const Attendance = require('../models/Attendance');
const User = require('../models/User');
const OfficeSettings = require('../models/OfficeSettings');
const { ApiError, ok, asyncHandler } = require('../utils/respond');
const {
  todayInTz,
  isValidDateStr,
  isValidMonthStr,
  monthRange,
  workingDaysBetween,
  atTime,
  dayjs,
} = require('../utils/time');
const { PRESENT_STATUSES } = require('../utils/attendanceCalc');
const { sendWorkbook } = require('../utils/excel');

function wantsXlsx(req) {
  const format = req.query.format || 'json';
  if (!['json', 'xlsx'].includes(format)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'format', message: 'Must be json or xlsx' },
    ]);
  }
  return format === 'xlsx';
}

async function activeEmployees(departmentId) {
  const filter = { role: 'employee', isActive: true };
  if (departmentId) {
    if (!mongoose.isValidObjectId(departmentId)) {
      throw new ApiError(400, 'Validation failed', [
        { field: 'departmentId', message: 'Must be a valid id' },
      ]);
    }
    filter.department = departmentId;
  }
  return User.find(filter).populate({ path: 'department', select: 'name' }).sort({ employeeId: 1 });
}

function departmentName(user) {
  return user.department ? user.department.name : '';
}

/** Per-employee aggregate rows over a date range. */
async function aggregateRange(employees, fromStr, toStr, todayStr) {
  const records = await Attendance.find({
    employee: { $in: employees.map((e) => e._id) },
    date: { $gte: fromStr, $lte: toStr },
  });
  const byEmployee = new Map();
  for (const r of records) {
    const key = String(r.employee);
    if (!byEmployee.has(key)) byEmployee.set(key, []);
    byEmployee.get(key).push(r);
  }

  const effectiveTo = toStr < todayStr ? toStr : todayStr;
  const workingDays = fromStr > effectiveTo ? 0 : workingDaysBetween(fromStr, effectiveTo);

  return employees.map((emp) => {
    const recs = byEmployee.get(String(emp._id)) || [];
    let presentDays = 0;
    let lateDays = 0;
    let leaveDays = 0;
    let totalWorkMinutes = 0;
    for (const r of recs) {
      if (PRESENT_STATUSES.includes(r.status)) presentDays += 1;
      if (r.isLate) lateDays += 1;
      if (r.status === 'ON_LEAVE') leaveDays += 1;
      totalWorkMinutes += r.workMinutes || 0;
    }
    return {
      employeeId: emp.employeeId,
      name: emp.name,
      department: departmentName(emp),
      presentDays,
      lateDays,
      absentDays: Math.max(0, workingDays - presentDays - leaveDays),
      leaveDays,
      totalWorkMinutes,
    };
  });
}

const AGGREGATE_COLUMNS = [
  { header: 'Employee ID', key: 'employeeId', width: 14 },
  { header: 'Name', key: 'name', width: 24 },
  { header: 'Department', key: 'department', width: 20 },
  { header: 'Present Days', key: 'presentDays', width: 14 },
  { header: 'Late Days', key: 'lateDays', width: 12 },
  { header: 'Absent Days', key: 'absentDays', width: 12 },
  { header: 'Leave Days', key: 'leaveDays', width: 12 },
  { header: 'Total Work Minutes', key: 'totalWorkMinutes', width: 18 },
];

// GET /reports/attendance
const attendanceReport = asyncHandler(async (req, res) => {
  const xlsx = wantsXlsx(req);
  const { type, departmentId } = req.query;
  const settings = await OfficeSettings.getSingleton();
  const todayStr = todayInTz(settings.timezone);

  if (!['daily', 'weekly', 'monthly'].includes(type)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'type', message: 'type must be daily, weekly or monthly' },
    ]);
  }

  const employees = await activeEmployees(departmentId);

  if (type === 'daily') {
    const date = req.query.date || todayStr;
    if (!isValidDateStr(date)) {
      throw new ApiError(400, 'Validation failed', [{ field: 'date', message: 'Use YYYY-MM-DD' }]);
    }

    const records = await Attendance.find({
      date,
      employee: { $in: employees.map((e) => e._id) },
    });
    const byEmployee = new Map(records.map((r) => [String(r.employee), r]));

    const rows = employees.map((emp) => {
      const r = byEmployee.get(String(emp._id)) || null;
      return {
        employeeId: emp.employeeId,
        name: emp.name,
        department: departmentName(emp),
        date,
        status: r ? r.status : 'ABSENT',
        checkIn: r && r.checkIn ? r.checkIn.toISOString() : null,
        checkOut: r && r.checkOut ? r.checkOut.toISOString() : null,
        workMinutes: r ? r.workMinutes : 0,
        isLate: r ? r.isLate : false,
        isEarlyOut: r ? r.isEarlyOut : false,
      };
    });

    if (!xlsx) {
      ok(res, rows);
      return;
    }
    const columns = [
      { header: 'Employee ID', key: 'employeeId', width: 14 },
      { header: 'Name', key: 'name', width: 24 },
      { header: 'Department', key: 'department', width: 20 },
      { header: 'Date', key: 'date', width: 12 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Check In', key: 'checkIn', width: 12 },
      { header: 'Check Out', key: 'checkOut', width: 12 },
      { header: 'Work Minutes', key: 'workMinutes', width: 14 },
      { header: 'Late', key: 'isLate', width: 8 },
      { header: 'Early Out', key: 'isEarlyOut', width: 10 },
    ];
    const xlsxRows = rows.map((row) => ({
      ...row,
      checkIn: row.checkIn ? dayjs(row.checkIn).tz(settings.timezone).format('HH:mm') : '',
      checkOut: row.checkOut ? dayjs(row.checkOut).tz(settings.timezone).format('HH:mm') : '',
      isLate: row.isLate ? 'YES' : 'NO',
      isEarlyOut: row.isEarlyOut ? 'YES' : 'NO',
    }));
    await sendWorkbook(res, `attendance-daily-${date}.xlsx`, 'Daily Attendance', columns, xlsxRows);
    return;
  }

  let fromStr;
  let toStr;
  let suffix;
  if (type === 'weekly') {
    const { from, to } = req.query;
    const errors = [];
    if (!from || !isValidDateStr(from)) errors.push({ field: 'from', message: 'Use YYYY-MM-DD' });
    if (!to || !isValidDateStr(to)) errors.push({ field: 'to', message: 'Use YYYY-MM-DD' });
    if (errors.length) throw new ApiError(400, 'Validation failed', errors);
    if (from > to) {
      throw new ApiError(400, 'Validation failed', [
        { field: 'to', message: 'to must be on or after from' },
      ]);
    }
    fromStr = from;
    toStr = to;
    suffix = `${from}_${to}`;
  } else {
    const month = req.query.month;
    if (!month || !isValidMonthStr(month)) {
      throw new ApiError(400, 'Validation failed', [{ field: 'month', message: 'Use YYYY-MM' }]);
    }
    [fromStr, toStr] = monthRange(month);
    suffix = month;
  }

  const rows = await aggregateRange(employees, fromStr, toStr, todayStr);
  if (!xlsx) {
    ok(res, rows);
    return;
  }
  await sendWorkbook(
    res,
    `attendance-${type}-${suffix}.xlsx`,
    'Attendance Report',
    AGGREGATE_COLUMNS,
    rows
  );
});

// GET /reports/working-hours?month=YYYY-MM
const workingHoursReport = asyncHandler(async (req, res) => {
  const xlsx = wantsXlsx(req);
  const settings = await OfficeSettings.getSingleton();
  const todayStr = todayInTz(settings.timezone);
  const month = req.query.month || todayStr.slice(0, 7);
  if (!isValidMonthStr(month)) {
    throw new ApiError(400, 'Validation failed', [{ field: 'month', message: 'Use YYYY-MM' }]);
  }

  const [fromStr, toStr] = monthRange(month);
  const employees = await activeEmployees(req.query.departmentId);
  const records = await Attendance.find({
    employee: { $in: employees.map((e) => e._id) },
    date: { $gte: fromStr, $lte: toStr },
  });
  const byEmployee = new Map();
  for (const r of records) {
    const key = String(r.employee);
    if (!byEmployee.has(key)) byEmployee.set(key, []);
    byEmployee.get(key).push(r);
  }

  const rows = employees.map((emp) => {
    const recs = byEmployee.get(String(emp._id)) || [];
    let totalWorkMinutes = 0;
    let daysWorked = 0;
    for (const r of recs) {
      totalWorkMinutes += r.workMinutes || 0;
      if (r.checkIn) daysWorked += 1;
    }
    return {
      employeeId: emp.employeeId,
      name: emp.name,
      department: departmentName(emp),
      totalWorkMinutes,
      averageWorkMinutes: daysWorked > 0 ? Math.round(totalWorkMinutes / daysWorked) : 0,
      daysWorked,
    };
  });

  if (!xlsx) {
    ok(res, rows);
    return;
  }
  const columns = [
    { header: 'Employee ID', key: 'employeeId', width: 14 },
    { header: 'Name', key: 'name', width: 24 },
    { header: 'Department', key: 'department', width: 20 },
    { header: 'Total Work Minutes', key: 'totalWorkMinutes', width: 18 },
    { header: 'Average Work Minutes', key: 'averageWorkMinutes', width: 20 },
    { header: 'Days Worked', key: 'daysWorked', width: 12 },
  ];
  await sendWorkbook(res, `working-hours-${month}.xlsx`, 'Working Hours', columns, rows);
});

function parseRange(req, settings) {
  const todayStr = todayInTz(settings.timezone);
  const from =
    req.query.from ||
    dayjs(todayStr, 'YYYY-MM-DD', true).subtract(29, 'day').format('YYYY-MM-DD');
  const to = req.query.to || todayStr;
  const errors = [];
  if (!isValidDateStr(from)) errors.push({ field: 'from', message: 'Use YYYY-MM-DD' });
  if (!isValidDateStr(to)) errors.push({ field: 'to', message: 'Use YYYY-MM-DD' });
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);
  if (from > to) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'to', message: 'to must be on or after from' },
    ]);
  }
  return { from, to };
}

// GET /reports/late-arrivals?from=&to=
const lateArrivalsReport = asyncHandler(async (req, res) => {
  const xlsx = wantsXlsx(req);
  const settings = await OfficeSettings.getSingleton();
  const { from, to } = parseRange(req, settings);

  const records = await Attendance.find({
    date: { $gte: from, $lte: to },
    isLate: true,
    checkIn: { $ne: null },
  })
    .populate({
      path: 'employee',
      select: 'employeeId name department',
      populate: { path: 'department', select: 'name' },
    })
    .sort({ date: 1 });

  const rows = records
    .filter((r) => r.employee)
    .map((r) => {
      const startOfDay = atTime(r.date, settings.workStartTime, settings.timezone);
      const minutesLate = Math.max(0, dayjs(r.checkIn).diff(startOfDay, 'minute'));
      return {
        employeeId: r.employee.employeeId,
        name: r.employee.name,
        department: r.employee.department ? r.employee.department.name : '',
        date: r.date,
        checkIn: r.checkIn.toISOString(),
        minutesLate,
      };
    });

  if (!xlsx) {
    ok(res, rows);
    return;
  }
  const columns = [
    { header: 'Employee ID', key: 'employeeId', width: 14 },
    { header: 'Name', key: 'name', width: 24 },
    { header: 'Department', key: 'department', width: 20 },
    { header: 'Date', key: 'date', width: 12 },
    { header: 'Check In', key: 'checkIn', width: 12 },
    { header: 'Minutes Late', key: 'minutesLate', width: 14 },
  ];
  const xlsxRows = rows.map((row) => ({
    ...row,
    checkIn: dayjs(row.checkIn).tz(settings.timezone).format('HH:mm'),
  }));
  await sendWorkbook(res, `late-arrivals-${from}_${to}.xlsx`, 'Late Arrivals', columns, xlsxRows);
});

// GET /reports/early-checkouts?from=&to=
const earlyCheckoutsReport = asyncHandler(async (req, res) => {
  const xlsx = wantsXlsx(req);
  const settings = await OfficeSettings.getSingleton();
  const { from, to } = parseRange(req, settings);

  const records = await Attendance.find({
    date: { $gte: from, $lte: to },
    isEarlyOut: true,
    checkOut: { $ne: null },
  })
    .populate({
      path: 'employee',
      select: 'employeeId name department',
      populate: { path: 'department', select: 'name' },
    })
    .sort({ date: 1 });

  const rows = records
    .filter((r) => r.employee)
    .map((r) => {
      const endOfDay = atTime(r.date, settings.workEndTime, settings.timezone);
      const minutesEarly = Math.max(0, endOfDay.diff(dayjs(r.checkOut), 'minute'));
      return {
        employeeId: r.employee.employeeId,
        name: r.employee.name,
        department: r.employee.department ? r.employee.department.name : '',
        date: r.date,
        checkOut: r.checkOut.toISOString(),
        minutesEarly,
      };
    });

  if (!xlsx) {
    ok(res, rows);
    return;
  }
  const columns = [
    { header: 'Employee ID', key: 'employeeId', width: 14 },
    { header: 'Name', key: 'name', width: 24 },
    { header: 'Department', key: 'department', width: 20 },
    { header: 'Date', key: 'date', width: 12 },
    { header: 'Check Out', key: 'checkOut', width: 12 },
    { header: 'Minutes Early', key: 'minutesEarly', width: 14 },
  ];
  const xlsxRows = rows.map((row) => ({
    ...row,
    checkOut: dayjs(row.checkOut).tz(settings.timezone).format('HH:mm'),
  }));
  await sendWorkbook(
    res,
    `early-checkouts-${from}_${to}.xlsx`,
    'Early Checkouts',
    columns,
    xlsxRows
  );
});

module.exports = { attendanceReport, workingHoursReport, lateArrivalsReport, earlyCheckoutsReport };
