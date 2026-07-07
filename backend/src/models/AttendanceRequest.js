const mongoose = require('mongoose');

const attendanceRequestSchema = new mongoose.Schema(
  {
    employee: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: String, required: true }, // YYYY-MM-DD
    type: {
      type: String,
      enum: ['MISSED_CHECK_IN', 'MISSED_CHECK_OUT', 'FULL_DAY', 'LEAVE'],
      required: true,
    },
    requestedCheckIn: { type: Date, default: null },
    requestedCheckOut: { type: Date, default: null },
    reason: { type: String, required: true, trim: true },
    status: { type: String, enum: ['PENDING', 'APPROVED', 'REJECTED'], default: 'PENDING' },
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    reviewNote: { type: String, default: null },
  },
  { timestamps: true, toJSON: { versionKey: false } }
);

attendanceRequestSchema.index({ employee: 1, createdAt: -1 });

module.exports = mongoose.model('AttendanceRequest', attendanceRequestSchema);
