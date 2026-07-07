const User = require('../models/User');
const { signToken } = require('../middleware/auth');
const { ApiError, ok, asyncHandler } = require('../utils/respond');

const USER_POPULATE = [
  { path: 'department', select: 'name description' },
  { path: 'designation', select: 'name description' },
];

async function populatedUser(id) {
  return User.findById(id).populate(USER_POPULATE);
}

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body || {};
  const errors = [];
  if (!email || typeof email !== 'string') errors.push({ field: 'email', message: 'Email is required' });
  if (!password || typeof password !== 'string') {
    errors.push({ field: 'password', message: 'Password is required' });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');
  if (!user || !(await user.comparePassword(password))) {
    throw new ApiError(401, 'Invalid email or password');
  }
  if (!user.isActive) throw new ApiError(401, 'This account has been deactivated');

  const token = signToken(user);
  const fullUser = await populatedUser(user._id);
  ok(res, { token, user: fullUser });
});

const me = asyncHandler(async (req, res) => {
  const user = await populatedUser(req.user._id);
  ok(res, user);
});

const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  const errors = [];
  if (!currentPassword) {
    errors.push({ field: 'currentPassword', message: 'Current password is required' });
  }
  if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
    errors.push({ field: 'newPassword', message: 'New password must be at least 6 characters' });
  }
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const user = await User.findById(req.user._id).select('+password');
  if (!(await user.comparePassword(currentPassword))) {
    throw new ApiError(400, 'Current password is incorrect', [
      { field: 'currentPassword', message: 'Current password is incorrect' },
    ]);
  }

  user.password = newPassword; // hashed by pre-save hook
  await user.save();
  ok(res, { message: 'Password changed successfully' });
});

module.exports = { login, me, changePassword, USER_POPULATE };
