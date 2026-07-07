const User = require('../models/User');
const Department = require('../models/Department');
const Designation = require('../models/Designation');
const { ApiError, ok, asyncHandler, escapeRegex } = require('../utils/respond');

/**
 * Shared CRUD for the two identical catalogs: departments and designations.
 * { _id, name, description? } — DELETE returns 409 when in use by an employee.
 */
function makeCatalogController(Model, label, userField) {
  const list = asyncHandler(async (req, res) => {
    const items = await Model.find().sort({ name: 1 });
    ok(res, items);
  });

  const create = asyncHandler(async (req, res) => {
    const { name, description } = req.body || {};
    if (!name || !String(name).trim()) {
      throw new ApiError(400, 'Validation failed', [
        { field: 'name', message: 'Name is required' },
      ]);
    }
    const trimmed = String(name).trim();
    const existing = await Model.findOne({ name: new RegExp(`^${escapeRegex(trimmed)}$`, 'i') });
    if (existing) throw new ApiError(409, `A ${label} with this name already exists`);

    const item = await Model.create({
      name: trimmed,
      description: description ? String(description).trim() : '',
    });
    ok(res, item, { status: 201 });
  });

  const update = asyncHandler(async (req, res) => {
    const item = await Model.findById(req.params.id);
    if (!item) throw new ApiError(404, `${capitalize(label)} not found`);

    const { name, description } = req.body || {};
    if (name !== undefined) {
      const trimmed = String(name).trim();
      if (!trimmed) {
        throw new ApiError(400, 'Validation failed', [
          { field: 'name', message: 'Name cannot be empty' },
        ]);
      }
      const existing = await Model.findOne({
        name: new RegExp(`^${escapeRegex(trimmed)}$`, 'i'),
        _id: { $ne: item._id },
      });
      if (existing) throw new ApiError(409, `A ${label} with this name already exists`);
      item.name = trimmed;
    }
    if (description !== undefined) {
      item.description = description === null ? '' : String(description).trim();
    }
    await item.save();
    ok(res, item);
  });

  const remove = asyncHandler(async (req, res) => {
    const item = await Model.findById(req.params.id);
    if (!item) throw new ApiError(404, `${capitalize(label)} not found`);

    const inUse = await User.countDocuments({ [userField]: item._id });
    if (inUse > 0) {
      throw new ApiError(
        409,
        `Cannot delete: this ${label} is in use by ${inUse} employee${inUse === 1 ? '' : 's'}`
      );
    }
    await item.deleteOne();
    ok(res, { message: `${capitalize(label)} deleted` });
  });

  return { list, create, update, remove };
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const departments = makeCatalogController(Department, 'department', 'department');
const designations = makeCatalogController(Designation, 'designation', 'designation');

module.exports = { departments, designations };
