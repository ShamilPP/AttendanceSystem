const multer = require('multer');
const { ApiError } = require('../utils/respond');

function notFoundHandler(req, res) {
  res.status(404).json({ success: false, message: `Route not found: ${req.method} ${req.originalUrl}` });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  let statusCode = 500;
  let message = 'Internal server error';
  let errors;

  if (err instanceof ApiError) {
    statusCode = err.statusCode;
    message = err.message;
    errors = err.errors;
  } else if (err instanceof multer.MulterError) {
    statusCode = 400;
    message =
      err.code === 'LIMIT_FILE_SIZE'
        ? 'File too large. Maximum allowed size is 10 MB'
        : `Upload error: ${err.message}`;
  } else if (err.name === 'ValidationError' && err.errors) {
    // Mongoose validation
    statusCode = 400;
    message = 'Validation failed';
    errors = Object.values(err.errors).map((e) => ({ field: e.path, message: e.message }));
  } else if (err.name === 'CastError') {
    statusCode = 404;
    message = 'Resource not found';
  } else if (err.code === 11000) {
    statusCode = 409;
    const field = Object.keys(err.keyPattern || err.keyValue || {})[0] || 'value';
    message = `Duplicate ${field}: a record with this ${field} already exists`;
  } else if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Invalid or expired token';
  } else if (err.type === 'entity.parse.failed') {
    statusCode = 400;
    message = 'Invalid JSON body';
  } else if (typeof err.statusCode === 'number' && err.statusCode >= 400 && err.statusCode < 500) {
    statusCode = err.statusCode;
    message = err.message || message;
  }

  if (statusCode >= 500) {
    // eslint-disable-next-line no-console
    console.error(err);
  }

  const body = { success: false, message };
  if (errors && errors.length) body.errors = errors;
  res.status(statusCode).json(body);
}

module.exports = { notFoundHandler, errorHandler };
