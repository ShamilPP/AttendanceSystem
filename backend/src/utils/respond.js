/**
 * Shared response envelope helpers.
 * Success: { success: true, data, pagination? }
 * Error:   { success: false, message, errors? }
 */

class ApiError extends Error {
  constructor(statusCode, message, errors = undefined) {
    super(message);
    this.statusCode = statusCode;
    if (Array.isArray(errors) && errors.length > 0) this.errors = errors;
  }
}

function ok(res, data, options = {}) {
  const body = { success: true, data };
  if (options.pagination) body.pagination = options.pagination;
  res.status(options.status || 200).json(body);
}

/** Parse ?page=&limit= with sane bounds. */
function parsePaging(query) {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const limit = Math.min(200, Math.max(1, parseInt(query.limit, 10) || 20));
  return { page, limit, skip: (page - 1) * limit };
}

function buildPagination(page, limit, total) {
  return { page, limit, total, totalPages: Math.ceil(total / limit) };
}

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

function escapeRegex(str) {
  return String(str).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

module.exports = { ApiError, ok, parsePaging, buildPagination, asyncHandler, escapeRegex };
