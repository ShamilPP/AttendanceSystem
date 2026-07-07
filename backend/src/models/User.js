const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    employeeId: { type: String, required: true, unique: true, trim: true },
    name: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: { type: String, required: true, select: false },
    role: { type: String, enum: ['admin', 'employee'], default: 'employee' },
    department: { type: mongoose.Schema.Types.ObjectId, ref: 'Department', default: null },
    designation: { type: mongoose.Schema.Types.ObjectId, ref: 'Designation', default: null },
    phone: { type: String, trim: true, default: '' },
    address: { type: String, trim: true, default: '' },
    joiningDate: { type: String, default: null }, // YYYY-MM-DD
    isActive: { type: Boolean, default: true },
  },
  {
    timestamps: true,
    toJSON: {
      versionKey: false,
      transform(doc, ret) {
        delete ret.password;
        return ret;
      },
    },
  }
);

userSchema.pre('save', async function preSave(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  return next();
});

userSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

/** Next auto-generated employee id: EMP-0001, EMP-0002, ... */
userSchema.statics.nextEmployeeId = async function nextEmployeeId() {
  const docs = await this.find({ employeeId: /^EMP-\d+$/ }).select('employeeId').lean();
  let max = 0;
  for (const d of docs) {
    const n = parseInt(d.employeeId.slice(4), 10);
    if (Number.isFinite(n) && n > max) max = n;
  }
  return `EMP-${String(max + 1).padStart(4, '0')}`;
};

module.exports = mongoose.model('User', userSchema);
