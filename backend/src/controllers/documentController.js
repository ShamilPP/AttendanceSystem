const path = require('path');
const fs = require('fs');
const DocumentModel = require('../models/Document');
const env = require('../config/env');
const { ApiError, ok, asyncHandler } = require('../utils/respond');
const { resolveEmployee } = require('../utils/employeeLookup');

const DOC_TYPES = ['ID_PROOF', 'COMPANY_ID', 'OTHER'];

function removeFileQuietly(filePath) {
  fs.promises.unlink(filePath).catch(() => {});
}

// POST /documents  [employee] — multipart: file, type, name
const upload = asyncHandler(async (req, res) => {
  const { type, name } = req.body || {};
  const errors = [];
  if (!req.file) errors.push({ field: 'file', message: 'File is required' });
  if (!DOC_TYPES.includes(type)) {
    errors.push({ field: 'type', message: `Must be one of ${DOC_TYPES.join(', ')}` });
  }
  if (!name || !String(name).trim()) errors.push({ field: 'name', message: 'Name is required' });
  if (errors.length) {
    if (req.file) removeFileQuietly(req.file.path);
    throw new ApiError(400, 'Validation failed', errors);
  }

  const doc = await DocumentModel.create({
    employee: req.user._id,
    type,
    name: String(name).trim(),
    fileName: req.file.originalname,
    storedName: req.file.filename,
    mimeType: req.file.mimetype,
    size: req.file.size,
  });

  ok(res, doc, { status: 201 });
});

// GET /documents/me  [employee]
const listMine = asyncHandler(async (req, res) => {
  const docs = await DocumentModel.find({ employee: req.user._id }).sort({ uploadedAt: -1 });
  ok(res, docs);
});

// GET /documents  [admin] ?employeeId=
const listAll = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.query.employeeId) {
    const employee = await resolveEmployee(req.query.employeeId);
    if (!employee) throw new ApiError(404, 'Employee not found');
    filter.employee = employee._id;
  }
  const docs = await DocumentModel.find(filter).sort({ uploadedAt: -1 });
  ok(res, docs);
});

async function findAuthorizedDocument(req) {
  const doc = await DocumentModel.findById(req.params.id);
  if (!doc) throw new ApiError(404, 'Document not found');
  const isOwner = String(doc.employee) === String(req.user._id);
  if (!isOwner && req.user.role !== 'admin') {
    throw new ApiError(403, 'You do not have permission to access this document');
  }
  return doc;
}

// GET /documents/:id/download  [any: owner or admin]
const download = asyncHandler(async (req, res) => {
  const doc = await findAuthorizedDocument(req);
  const filePath = path.join(env.UPLOADS_DIR, doc.storedName);
  if (!fs.existsSync(filePath)) throw new ApiError(404, 'Stored file not found on server');

  res.setHeader('Content-Type', doc.mimeType);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${encodeURIComponent(doc.fileName)}"`
  );
  const stream = fs.createReadStream(filePath);
  stream.on('error', () => {
    if (!res.headersSent) res.status(500);
    res.end();
  });
  stream.pipe(res);
});

// DELETE /documents/:id  [any: owner or admin]
const remove = asyncHandler(async (req, res) => {
  const doc = await findAuthorizedDocument(req);
  removeFileQuietly(path.join(env.UPLOADS_DIR, doc.storedName));
  await doc.deleteOne();
  ok(res, { message: 'Document deleted' });
});

module.exports = { upload, listMine, listAll, download, remove };
