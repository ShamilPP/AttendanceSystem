const jwt = require('jsonwebtoken');
const env = require('../config/env');
const User = require('../models/User');
const { ApiError, asyncHandler } = require('../utils/respond');

/** Verifies the Bearer JWT and attaches the active user document to req.user. */
const authenticate = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) {
    throw new ApiError(401, 'Authentication required');
  }
  const token = header.slice(7).trim();

  let decoded;
  try {
    decoded = jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] });
  } catch {
    throw new ApiError(401, 'Invalid or expired token');
  }

  const user = await User.findById(decoded.sub);
  if (!user || !user.isActive) {
    throw new ApiError(401, 'Invalid or expired token');
  }

  req.user = user;
  return next();
});

/** Role guard — 403 when the authenticated user's role is not allowed. */
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    return next(new ApiError(403, 'You do not have permission to perform this action'));
  }
  return next();
};

function signToken(user) {
  return jwt.sign(
    { sub: user._id.toString(), role: user.role, employeeId: user.employeeId },
    env.JWT_SECRET,
    { algorithm: 'HS256', expiresIn: env.JWT_EXPIRES_IN }
  );
}

module.exports = { authenticate, requireRole, signToken };
