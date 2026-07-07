const { dayjs, atTime } = require('./time');

const PRESENT_STATUSES = ['PRESENT', 'LATE', 'HALF_DAY'];

/**
 * Recompute derived fields on an attendance record:
 * workMinutes (full checkIn→checkOut span), isLate, isEarlyOut.
 * workMinutes is 0 until checkOut is set.
 */
function recomputeAttendance(att, settings, now = new Date()) {
  const tz = settings.timezone;

  if (att.checkIn && att.checkOut) {
    const totalMs = Math.max(0, new Date(att.checkOut).getTime() - new Date(att.checkIn).getTime());
    att.workMinutes = Math.round(totalMs / 60000);
  } else {
    att.workMinutes = 0;
  }

  if (att.checkIn) {
    const lateCutoff = atTime(att.date, settings.workStartTime, tz).add(
      settings.lateToleranceMinutes,
      'minute'
    );
    att.isLate = dayjs(att.checkIn).isAfter(lateCutoff);
  } else {
    att.isLate = false;
  }

  if (att.checkOut) {
    const earlyCutoff = atTime(att.date, settings.workEndTime, tz).subtract(
      settings.earlyLeaveToleranceMinutes,
      'minute'
    );
    att.isEarlyOut = dayjs(att.checkOut).isBefore(earlyCutoff);
  } else {
    att.isEarlyOut = false;
  }

  return att;
}

/**
 * Re-derive PRESENT/LATE from isLate when the status is a plain "worked" status.
 * Explicit ON_LEAVE / HALF_DAY / ABSENT settings are preserved.
 */
function deriveWorkedStatus(att) {
  if (att.checkIn && (att.status === 'PRESENT' || att.status === 'LATE' || !att.status)) {
    att.status = att.isLate ? 'LATE' : 'PRESENT';
  }
  return att;
}

/** Populated `employee` shape used inside attendance responses. */
const ATTENDANCE_EMPLOYEE_POPULATE = {
  path: 'employee',
  select: 'employeeId name department',
  populate: { path: 'department', select: 'name' },
};

/** Live status for the admin live view. */
function liveStatusOf(att) {
  if (!att) return 'NOT_IN';
  if (att.status === 'ON_LEAVE') return 'ON_LEAVE';
  if (att.checkOut) return 'CHECKED_OUT';
  if (att.checkIn) return 'WORKING';
  return 'NOT_IN';
}

module.exports = {
  PRESENT_STATUSES,
  recomputeAttendance,
  deriveWorkedStatus,
  liveStatusOf,
  ATTENDANCE_EMPLOYEE_POPULATE,
};
