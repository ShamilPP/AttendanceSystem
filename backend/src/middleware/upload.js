const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');
const env = require('../config/env');
const { ApiError } = require('../utils/respond');

fs.mkdirSync(env.UPLOADS_DIR, { recursive: true });

const DOC_MIME_TYPES = new Set(['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']);
const DOC_EXTENSIONS = new Set(['.pdf', '.jpg', '.jpeg', '.png']);

/** Document uploads: disk storage, 10 MB, pdf/jpg/jpeg/png only. */
const documentUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, env.UPLOADS_DIR),
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase();
      cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (DOC_MIME_TYPES.has(file.mimetype) && DOC_EXTENSIONS.has(ext)) return cb(null, true);
    return cb(new ApiError(400, 'Invalid file type. Only PDF, JPG, JPEG and PNG files are allowed'));
  },
});

const XLSX_MIME_TYPES = new Set([
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/octet-stream',
]);

/** Employee import: in-memory .xlsx only. */
const importUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (ext === '.xlsx' && XLSX_MIME_TYPES.has(file.mimetype)) return cb(null, true);
    return cb(new ApiError(400, 'Invalid file type. Only .xlsx files are allowed'));
  },
});

module.exports = { documentUpload, importUpload };
