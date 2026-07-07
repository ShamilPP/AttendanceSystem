const AttendanceRequest = require('../models/AttendanceRequest');
const Attendance = require('../models/Attendance');
const OfficeSettings = require('../models/OfficeSettings');
const {
  ApiError,
  ok,
  asyncHandler,
  parsePaging,
  buildPagination,
} = require('../utils/respond');
const { isValidDateStr, parseIso } = require('../utils/time');
const { recomputeAttendance, deriveWorkedStatus } = require('../utils/attendanceCalc');

const REQUEST_TYPES = ['MISSED_CHECK_IN', 'MISSED_CHECK_OUT', 'FULL_DAY', 'LEAVE'];
const REQUEST_STATUSES = ['PENDING', 'APPROVED', 'REJECTED'];

const REQUEST_POPULATE = { path: 'employee', select: 'employeeId name' };

// POST /attendance/requests  [employee]
const createRequest = asyncHandler(async (req, res) => {
  const { date, type, requestedCheckIn, requestedCheckOut, reason } = req.body || {};

  const errors = [];
  if (!date || !isValidDateStr(date)) errors.push({ field: 'date', message: 'Use YYYY-MM-DD' });
  if (!REQUEST_TYPES.includes(type)) {
    errors.push({ field: 'type', message: `Must be one of ${REQUEST_TYPES.join(', ')}` });
  }
  if (!reason || !String(reason).trim()) {
    errors.push({ field: 'reason', message: 'Reason is required' });
  }

  let checkInDate = null;
  let checkOutDate = null;
  if (requestedCheckIn !== undefined && requestedCheckIn !== null && requestedCheckIn !== '') {
    checkInDate = parseIso(requestedCheckIn);
    if (!checkInDate) {
      errors.push({ field: 'requestedCheckIn', message: 'Must be a valid ISO timestamp' });
    }
  }
  if (requestedCheckOut !== undefined && requestedCheckOut !== null && requestedCheckOut !== '') {
    checkOutDate = parseIso(requestedCheckOut);
    if (!checkOutDate) {
      errors.push({ field: 'requestedCheckOut', message: 'Must be a valid ISO timestamp' });
    }
  }
  if ((type === 'MISSED_CHECK_IN' || type === 'FULL_DAY') && !checkInDate) {
    errors.push({ field: 'requestedCheckIn', message: `requestedCheckIn is required for ${type}` });
  }
  if ((type === 'MISSED_CHECK_OUT' || type === 'FULL_DAY') && !checkOutDate) {
    errors.push({ field: 'requestedCheckOut', message: `requestedCheckOut is required for ${type}` });
  }
  if (checkInDate && checkOutDate && checkOutDate < checkInDate) {
    errors.push({ field: 'requestedCheckOut', message: 'Must be after requestedCheckIn' });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const request = await AttendanceRequest.create({
    employee: req.user._id,
    date,
    type,
    requestedCheckIn: checkInDate,
    requestedCheckOut: checkOutDate,
    reason: String(reason).trim(),
  });

  await request.populate(REQUEST_POPULATE);
  ok(res, request, { status: 201 });
});

// GET /attendance/requests/me  [employee]
const myRequests = asyncHandler(async (req, res) => {
  const { status } = req.query;
  const { page, limit, skip } = parsePaging(req.query);

  if (status && !REQUEST_STATUSES.includes(status)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'status', message: `Must be one of ${REQUEST_STATUSES.join(', ')}` },
    ]);
  }

  const filter = { employee: req.user._id };
  if (status) filter.status = status;

  const [total, requests] = await Promise.all([
    AttendanceRequest.countDocuments(filter),
    AttendanceRequest.find(filter)
      .populate(REQUEST_POPULATE)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
  ]);

  ok(res, requests, { pagination: buildPagination(page, limit, total) });
});

// GET /attendance/requests  [admin]
const listRequests = asyncHandler(async (req, res) => {
  const { status } = req.query;
  const { page, limit, skip } = parsePaging(req.query);

  if (status && !REQUEST_STATUSES.includes(status)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'status', message: `Must be one of ${REQUEST_STATUSES.join(', ')}` },
    ]);
  }

  const filter = {};
  if (status) filter.status = status;

  const [total, requests] = await Promise.all([
    AttendanceRequest.countDocuments(filter),
    AttendanceRequest.find(filter)
      .populate(REQUEST_POPULATE)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
  ]);

  ok(res, requests, { pagination: buildPagination(page, limit, total) });
});

/** Apply an approved request's values onto the attendance record. */
async function applyApprovedRequest(request, settings) {
  let att = await Attendance.findOne({ employee: request.employee, date: request.date });
  if (!att) att = new Attendance({ employee: request.employee, date: request.date });

  if (request.type === 'LEAVE') {
    att.status = 'ON_LEAVE';
    recomputeAttendance(att, settings);
    await att.save();
    return att;
  }

  if (request.type === 'MISSED_CHECK_IN' || request.type === 'FULL_DAY') {
    att.checkIn = request.requestedCheckIn;
  }
  if (request.type === 'MISSED_CHECK_OUT' || request.type === 'FULL_DAY') {
    att.checkOut = request.requestedCheckOut;
  }
  recomputeAttendance(att, settings);
  deriveWorkedStatus(att);
  await att.save();
  return att;
}

// PUT /attendance/requests/:id  [admin]
const reviewRequest = asyncHandler(async (req, res) => {
  const { status, reviewNote } = req.body || {};
  if (!['APPROVED', 'REJECTED'].includes(status)) {
    throw new ApiError(400, 'Validation failed', [
      { field: 'status', message: 'Must be APPROVED or REJECTED' },
    ]);
  }

  const request = await AttendanceRequest.findById(req.params.id);
  if (!request) throw new ApiError(404, 'Attendance request not found');
  if (request.status !== 'PENDING') {
    throw new ApiError(409, `This request has already been ${request.status.toLowerCase()}`);
  }

  if (status === 'APPROVED') {
    const settings = await OfficeSettings.getSingleton();
    await applyApprovedRequest(request, settings);
  }

  request.status = status;
  request.reviewedBy = req.user._id;
  request.reviewNote = reviewNote ? String(reviewNote).trim() : null;
  await request.save();
  await request.populate(REQUEST_POPULATE);

  ok(res, request);
});

module.exports = { createRequest, myRequests, listRequests, reviewRequest };
