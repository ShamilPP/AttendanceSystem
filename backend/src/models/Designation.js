const mongoose = require('mongoose');

const designationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, unique: true, trim: true },
    description: { type: String, trim: true, default: '' },
  },
  { timestamps: true, toJSON: { versionKey: false } }
);

module.exports = mongoose.model('Designation', designationSchema);
