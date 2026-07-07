const mongoose = require('mongoose');
const User = require('../models/User');

/**
 * Resolve an employee reference that may be either a Mongo _id
 * or a human employee code such as "EMP-0001".
 */
async function resolveEmployee(idOrCode) {
  if (!idOrCode) return null;
  const value = String(idOrCode).trim();
  if (mongoose.isValidObjectId(value)) {
    const byId = await User.findById(value);
    if (byId) return byId;
  }
  return User.findOne({ employeeId: value });
}

module.exports = { resolveEmployee };
