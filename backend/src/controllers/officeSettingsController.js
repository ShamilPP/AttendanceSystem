const OfficeSettings = require('../models/OfficeSettings');
const { ApiError, ok, asyncHandler } = require('../utils/respond');
const { isValidHm, dayjs } = require('../utils/time');

// GET /office-settings
const getSettings = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  ok(res, settings);
});

// PUT /office-settings — full or partial update
const updateSettings = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  const body = req.body || {};
  const errors = [];

  const numberField = (field, { min, max }) => {
    if (body[field] === undefined) return;
    const value = Number(body[field]);
    if (!Number.isFinite(value) || value < min || value > max) {
      errors.push({ field, message: `Must be a number between ${min} and ${max}` });
      return;
    }
    settings[field] = value;
  };

  numberField('latitude', { min: -90, max: 90 });
  numberField('longitude', { min: -180, max: 180 });
  numberField('radiusMeters', { min: 1, max: 100000 });
  numberField('lateToleranceMinutes', { min: 0, max: 480 });
  numberField('earlyLeaveToleranceMinutes', { min: 0, max: 480 });

  for (const field of ['workStartTime', 'workEndTime']) {
    if (body[field] === undefined) continue;
    if (!isValidHm(body[field])) {
      errors.push({ field, message: 'Must be a 24h time string HH:mm' });
    } else {
      settings[field] = body[field];
    }
  }

  if (body.timezone !== undefined) {
    try {
      dayjs().tz(String(body.timezone));
      settings.timezone = String(body.timezone);
    } catch {
      errors.push({ field: 'timezone', message: 'Unknown IANA timezone' });
    }
  }

  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  await settings.save();
  ok(res, settings);
});

module.exports = { getSettings, updateSettings };
