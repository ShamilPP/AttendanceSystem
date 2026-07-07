const mongoose = require('mongoose');
const User = require('../models/User');
const Department = require('../models/Department');
const Designation = require('../models/Designation');
const { USER_POPULATE } = require('./authController');
const {
  ApiError,
  ok,
  asyncHandler,
  parsePaging,
  buildPagination,
  escapeRegex,
} = require('../utils/respond');
const { isValidDateStr, dayjs } = require('../utils/time');
const { sendWorkbook, loadWorkbook, cellValue } = require('../utils/excel');

const EMAIL_RE = /^\S+@\S+\.\S+$/;

function normalizeJoiningDate(value, errors, field = 'joiningDate') {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  if (value instanceof Date) return dayjs(value).format('YYYY-MM-DD');
  if (isValidDateStr(value)) return value;
  const parsed = dayjs(String(value));
  if (parsed.isValid()) return parsed.format('YYYY-MM-DD');
  errors.push({ field, message: 'Must be a valid date (YYYY-MM-DD)' });
  return undefined;
}

async function validateRefs({ departmentId, designationId }, errors) {
  const result = {};
  if (departmentId !== undefined) {
    if (!mongoose.isValidObjectId(departmentId) || !(await Department.findById(departmentId))) {
      errors.push({ field: 'departmentId', message: 'Department not found' });
    } else {
      result.department = departmentId;
    }
  }
  if (designationId !== undefined) {
    if (!mongoose.isValidObjectId(designationId) || !(await Designation.findById(designationId))) {
      errors.push({ field: 'designationId', message: 'Designation not found' });
    } else {
      result.designation = designationId;
    }
  }
  return result;
}

// GET /employees
const list = asyncHandler(async (req, res) => {
  const { search, departmentId, designationId, isActive } = req.query;
  const { page, limit, skip } = parsePaging(req.query);

  const filter = {};
  if (search) {
    const rx = new RegExp(escapeRegex(search), 'i');
    filter.$or = [{ name: rx }, { email: rx }, { employeeId: rx }];
  }
  if (departmentId) {
    if (!mongoose.isValidObjectId(departmentId)) {
      throw new ApiError(400, 'Invalid departmentId', [
        { field: 'departmentId', message: 'Must be a valid id' },
      ]);
    }
    filter.department = departmentId;
  }
  if (designationId) {
    if (!mongoose.isValidObjectId(designationId)) {
      throw new ApiError(400, 'Invalid designationId', [
        { field: 'designationId', message: 'Must be a valid id' },
      ]);
    }
    filter.designation = designationId;
  }
  if (isActive === 'true' || isActive === 'false') filter.isActive = isActive === 'true';

  const [total, users] = await Promise.all([
    User.countDocuments(filter),
    User.find(filter).populate(USER_POPULATE).sort({ employeeId: 1 }).skip(skip).limit(limit),
  ]);

  ok(res, users, { pagination: buildPagination(page, limit, total) });
});

// POST /employees
const create = asyncHandler(async (req, res) => {
  const {
    employeeId,
    name,
    email,
    password,
    departmentId,
    designationId,
    phone,
    address,
    joiningDate,
    role,
  } = req.body || {};

  const errors = [];
  if (!name || !String(name).trim()) errors.push({ field: 'name', message: 'Name is required' });
  if (!email || !EMAIL_RE.test(String(email))) {
    errors.push({ field: 'email', message: 'A valid email is required' });
  }
  if (!password || String(password).length < 6) {
    errors.push({ field: 'password', message: 'Password must be at least 6 characters' });
  }
  if (!departmentId) errors.push({ field: 'departmentId', message: 'Department is required' });
  if (!designationId) errors.push({ field: 'designationId', message: 'Designation is required' });
  if (role !== undefined && !['admin', 'employee'].includes(role)) {
    errors.push({ field: 'role', message: 'Role must be admin or employee' });
  }

  const refs = departmentId && designationId ? await validateRefs({ departmentId, designationId }, errors) : {};
  const normalizedJoining = normalizeJoiningDate(joiningDate, errors);
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  const normalizedEmail = String(email).toLowerCase().trim();
  if (await User.findOne({ email: normalizedEmail })) {
    throw new ApiError(409, 'An account with this email already exists');
  }

  let finalEmployeeId = employeeId && String(employeeId).trim();
  if (finalEmployeeId) {
    if (await User.findOne({ employeeId: finalEmployeeId })) {
      throw new ApiError(409, 'An account with this employeeId already exists');
    }
  } else {
    finalEmployeeId = await User.nextEmployeeId();
  }

  const user = await User.create({
    employeeId: finalEmployeeId,
    name: String(name).trim(),
    email: normalizedEmail,
    password: String(password),
    role: role || 'employee',
    department: refs.department,
    designation: refs.designation,
    phone: phone ? String(phone).trim() : '',
    address: address ? String(address).trim() : '',
    joiningDate: normalizedJoining === undefined ? null : normalizedJoining,
  });

  const created = await User.findById(user._id).populate(USER_POPULATE);
  ok(res, created, { status: 201 });
});

// GET /employees/:id
const getOne = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id).populate(USER_POPULATE);
  if (!user) throw new ApiError(404, 'Employee not found');
  ok(res, user);
});

// PUT /employees/:id
const update = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id).select('+password');
  if (!user) throw new ApiError(404, 'Employee not found');

  const {
    employeeId,
    name,
    email,
    password,
    departmentId,
    designationId,
    phone,
    address,
    joiningDate,
    role,
    isActive,
  } = req.body || {};

  const errors = [];
  if (name !== undefined && !String(name).trim()) {
    errors.push({ field: 'name', message: 'Name cannot be empty' });
  }
  if (email !== undefined && !EMAIL_RE.test(String(email))) {
    errors.push({ field: 'email', message: 'A valid email is required' });
  }
  if (password !== undefined && password !== '' && String(password).length < 6) {
    errors.push({ field: 'password', message: 'Password must be at least 6 characters' });
  }
  if (role !== undefined && !['admin', 'employee'].includes(role)) {
    errors.push({ field: 'role', message: 'Role must be admin or employee' });
  }
  const refs = await validateRefs({ departmentId, designationId }, errors);
  const normalizedJoining = normalizeJoiningDate(joiningDate, errors);
  if (errors.length) throw new ApiError(400, 'Validation failed', errors);

  if (email !== undefined) {
    const normalizedEmail = String(email).toLowerCase().trim();
    const existing = await User.findOne({ email: normalizedEmail, _id: { $ne: user._id } });
    if (existing) throw new ApiError(409, 'An account with this email already exists');
    user.email = normalizedEmail;
  }
  if (employeeId !== undefined && String(employeeId).trim()) {
    const trimmed = String(employeeId).trim();
    const existing = await User.findOne({ employeeId: trimmed, _id: { $ne: user._id } });
    if (existing) throw new ApiError(409, 'An account with this employeeId already exists');
    user.employeeId = trimmed;
  }
  if (name !== undefined) user.name = String(name).trim();
  if (password !== undefined && password !== '') user.password = String(password);
  if (refs.department !== undefined) user.department = refs.department;
  if (refs.designation !== undefined) user.designation = refs.designation;
  if (phone !== undefined) user.phone = phone === null ? '' : String(phone).trim();
  if (address !== undefined) user.address = address === null ? '' : String(address).trim();
  if (normalizedJoining !== undefined) user.joiningDate = normalizedJoining;
  if (role !== undefined) user.role = role;
  if (isActive !== undefined) user.isActive = isActive === true || isActive === 'true';

  await user.save();
  const updated = await User.findById(user._id).populate(USER_POPULATE);
  ok(res, updated);
});

// DELETE /employees/:id
const remove = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) throw new ApiError(404, 'Employee not found');

  if (req.query.hard === 'true') {
    await user.deleteOne();
    ok(res, { message: 'Employee permanently deleted' });
    return;
  }
  user.isActive = false;
  await user.save();
  ok(res, { message: 'Employee deactivated' });
});

const IMPORT_COLUMNS = [
  'Employee ID',
  'Name',
  'Email',
  'Password',
  'Department',
  'Designation',
  'Phone',
  'Address',
  'Joining Date',
];

async function findOrCreateByName(Model, name) {
  const trimmed = String(name).trim();
  const existing = await Model.findOne({ name: new RegExp(`^${escapeRegex(trimmed)}$`, 'i') });
  if (existing) return existing;
  return Model.create({ name: trimmed });
}

// POST /employees/import
const importEmployees = asyncHandler(async (req, res) => {
  if (!req.file) {
    throw new ApiError(400, 'File is required', [
      { field: 'file', message: 'Upload an .xlsx file in the "file" field' },
    ]);
  }

  let workbook;
  try {
    workbook = await loadWorkbook(req.file.buffer);
  } catch {
    throw new ApiError(400, 'Could not read the file. Make sure it is a valid .xlsx workbook');
  }
  const sheet = workbook.worksheets[0];
  if (!sheet) throw new ApiError(400, 'The workbook contains no worksheets');

  const colIndex = {};
  sheet.getRow(1).eachCell({ includeEmpty: false }, (cell, col) => {
    const header = String(cell.text || '').trim();
    if (IMPORT_COLUMNS.includes(header) && colIndex[header] === undefined) colIndex[header] = col;
  });
  const requiredHeaders = ['Name', 'Email', 'Password', 'Department', 'Designation'];
  const missingHeaders = requiredHeaders.filter((h) => colIndex[h] === undefined);
  if (missingHeaders.length) {
    throw new ApiError(
      400,
      `Invalid template: missing required column(s): ${missingHeaders.join(', ')}`
    );
  }

  let imported = 0;
  let skipped = 0;
  const rowErrors = [];
  const seenEmails = new Set();
  const seenEmployeeIds = new Set();

  for (let rowNumber = 2; rowNumber <= sheet.rowCount; rowNumber += 1) {
    const row = sheet.getRow(rowNumber);

    const rawEmployeeId = String(cellValue(row, colIndex['Employee ID']) || '').trim();
    const name = String(cellValue(row, colIndex.Name) || '').trim();
    const emailRaw = String(cellValue(row, colIndex.Email) || '').trim();
    const password = String(cellValue(row, colIndex.Password) || '').trim();
    const departmentName = String(cellValue(row, colIndex.Department) || '').trim();
    const designationName = String(cellValue(row, colIndex.Designation) || '').trim();
    const phone = String(cellValue(row, colIndex.Phone) || '').trim();
    const address = String(cellValue(row, colIndex.Address) || '').trim();
    const joiningRaw = cellValue(row, colIndex['Joining Date']);

    // Skip fully empty rows silently
    if (!rawEmployeeId && !name && !emailRaw && !password && !departmentName && !designationName) {
      continue;
    }

    try {
      if (!name) throw new Error('Name is required');
      const email = emailRaw.toLowerCase();
      if (!email || !EMAIL_RE.test(email)) throw new Error('A valid Email is required');
      if (!password || password.length < 6) {
        throw new Error('Password is required (min 6 characters)');
      }
      if (!departmentName) throw new Error('Department is required');
      if (!designationName) throw new Error('Designation is required');

      if (seenEmails.has(email)) throw new Error(`Duplicate email in file: ${email}`);
      if (await User.findOne({ email })) throw new Error(`Email already exists: ${email}`);

      let employeeId = rawEmployeeId;
      if (employeeId) {
        if (seenEmployeeIds.has(employeeId)) {
          throw new Error(`Duplicate Employee ID in file: ${employeeId}`);
        }
        if (await User.findOne({ employeeId })) {
          throw new Error(`Employee ID already exists: ${employeeId}`);
        }
      } else {
        employeeId = await User.nextEmployeeId();
      }

      let joiningDate = null;
      if (joiningRaw instanceof Date) {
        joiningDate = dayjs(joiningRaw).format('YYYY-MM-DD');
      } else if (String(joiningRaw).trim()) {
        const parsed = dayjs(String(joiningRaw).trim());
        if (!parsed.isValid()) throw new Error(`Invalid Joining Date: ${joiningRaw}`);
        joiningDate = parsed.format('YYYY-MM-DD');
      }

      const department = await findOrCreateByName(Department, departmentName);
      const designation = await findOrCreateByName(Designation, designationName);

      await User.create({
        employeeId,
        name,
        email,
        password,
        role: 'employee',
        department: department._id,
        designation: designation._id,
        phone,
        address,
        joiningDate,
      });

      seenEmails.add(email);
      seenEmployeeIds.add(employeeId);
      imported += 1;
    } catch (err) {
      skipped += 1;
      rowErrors.push({ row: rowNumber, message: err.message || 'Failed to import row' });
    }
  }

  ok(res, { imported, skipped, errors: rowErrors });
});

// GET /employees/export
const exportEmployees = asyncHandler(async (req, res) => {
  const users = await User.find({ role: 'employee' })
    .populate(USER_POPULATE)
    .sort({ employeeId: 1 });

  const columns = [
    { header: 'Employee ID', key: 'employeeId', width: 14 },
    { header: 'Name', key: 'name', width: 24 },
    { header: 'Email', key: 'email', width: 28 },
    { header: 'Department', key: 'department', width: 20 },
    { header: 'Designation', key: 'designation', width: 24 },
    { header: 'Phone', key: 'phone', width: 18 },
    { header: 'Address', key: 'address', width: 32 },
    { header: 'Joining Date', key: 'joiningDate', width: 14 },
  ];
  const rows = users.map((u) => ({
    employeeId: u.employeeId,
    name: u.name,
    email: u.email,
    department: u.department ? u.department.name : '',
    designation: u.designation ? u.designation.name : '',
    phone: u.phone || '',
    address: u.address || '',
    joiningDate: u.joiningDate || '',
  }));

  const today = dayjs().format('YYYY-MM-DD');
  await sendWorkbook(res, `employees-${today}.xlsx`, 'Employees', columns, rows);
});

module.exports = { list, create, getOne, update, remove, importEmployees, exportEmployees };
