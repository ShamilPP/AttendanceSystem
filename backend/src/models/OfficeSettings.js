const mongoose = require('mongoose');

const DEFAULTS = {
  latitude: 25.1972,
  longitude: 55.2744,
  radiusMeters: 150,
  workStartTime: '09:00',
  workEndTime: '18:00',
  lateToleranceMinutes: 10,
  earlyLeaveToleranceMinutes: 10,
  timezone: 'Asia/Dubai',
};

const officeSettingsSchema = new mongoose.Schema(
  {
    latitude: { type: Number, required: true, default: DEFAULTS.latitude },
    longitude: { type: Number, required: true, default: DEFAULTS.longitude },
    radiusMeters: { type: Number, required: true, default: DEFAULTS.radiusMeters },
    workStartTime: { type: String, required: true, default: DEFAULTS.workStartTime },
    workEndTime: { type: String, required: true, default: DEFAULTS.workEndTime },
    lateToleranceMinutes: { type: Number, required: true, default: DEFAULTS.lateToleranceMinutes },
    earlyLeaveToleranceMinutes: {
      type: Number,
      required: true,
      default: DEFAULTS.earlyLeaveToleranceMinutes,
    },
    timezone: { type: String, required: true, default: DEFAULTS.timezone },
  },
  { timestamps: true, toJSON: { versionKey: false } }
);

/** Singleton accessor — creates the document with defaults on first use. */
officeSettingsSchema.statics.getSingleton = async function getSingleton() {
  let settings = await this.findOne();
  if (!settings) settings = await this.create({});
  return settings;
};

officeSettingsSchema.statics.DEFAULTS = DEFAULTS;

module.exports = mongoose.model('OfficeSettings', officeSettingsSchema);
