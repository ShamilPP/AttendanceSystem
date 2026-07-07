const { dayjs, atTime } = require('./time');

const PRESENT_STATUSES = ['PRESENT', 'LATE', 'HALF_DAY'];

/**
 * Recompute derived fields on an attendance record:
 * breakMinutes, workMinutes (excludes breaks), isLate, isEarlyOut.
 * Open intervals (no checkOut / open break) are measured up to `now`.
 */
function recomputeAttendance(att, settings, now = new Date()) {
  const tz = settings.timezone;
  const endRef = att.checkOut ? new Date(att.checkOut) : now;

  let breakMs = 0;
  for (const b of att.breaks || []) {
    if (!b.start) continue;
    const start = new Date(b.start);
    const end = b.end ? new Date(b.end) : endRef;
    breakMs += Math.max(0, end.getTime() - start.getTime());
  }
  att.breakMinutes = Math.round(breakMs / 60000);

  if (att.checkIn) {
    const totalMs = Math.max(0, endRef.getTime() - new Date(att.checkIn).getTime());
    att.workMinutes = Math.max(0, Math.round((totalMs - breakMs) / 60000));
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
  if ((att.breaks || []).some((b) => b.start && !b.end)) return 'ON_BREAK';
  if (att.checkIn) return 'WORKING';
  return 'NOT_IN';
}

function hasOpenBreak(att) {
  return !!att && (att.breaks || []).some((b) => b.start && !b.end);
}

module.exports = {
  PRESENT_STATUSES,
  recomputeAttendance,
  deriveWorkedStatus,
  liveStatusOf,
  hasOpenBreak,
  ATTENDANCE_EMPLOYEE_POPULATE,
};
