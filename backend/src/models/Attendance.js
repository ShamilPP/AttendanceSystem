const mongoose = require('mongoose');

const breakSchema = new mongoose.Schema(
  {
    start: { type: Date, required: true },
    end: { type: Date, default: null },
  },
  { _id: false }
);

const locationSchema = new mongoose.Schema(
  {
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
  },
  { _id: false }
);

const correctionSchema = new mongoose.Schema(
  {
    correctedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    note: { type: String, required: true },
    correctedAt: { type: Date, required: true },
  },
  { _id: false }
);

const attendanceSchema = new mongoose.Schema(
  {
    employee: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: String, required: true }, // YYYY-MM-DD (office timezone calendar day)
    checkIn: { type: Date, default: null },
    checkOut: { type: Date, default: null },
    breaks: { type: [breakSchema], default: [] },
    workMinutes: { type: Number, default: 0 },
    breakMinutes: { type: Number, default: 0 },
    status: {
      type: String,
      enum: ['PRESENT', 'LATE', 'ABSENT', 'ON_LEAVE', 'HALF_DAY'],
      default: 'PRESENT',
    },
    isLate: { type: Boolean, default: false },
    isEarlyOut: { type: Boolean, default: false },
    checkInLocation: { type: locationSchema, default: undefined },
    checkOutLocation: { type: locationSchema, default: undefined },
    correction: { type: correctionSchema, default: undefined },
  },
  { timestamps: true, toJSON: { versionKey: false } }
);

attendanceSchema.index({ employee: 1, date: 1 }, { unique: true });
attendanceSchema.index({ date: 1 });

module.exports = mongoose.model('Attendance', attendanceSchema);
