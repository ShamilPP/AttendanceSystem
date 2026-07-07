/**
 * Idempotent database seed (wipe-and-recreate).
 *
 * Creates:
 *  - admin:          admin@company.com / Admin@123
 *  - office settings: lat 25.1972, lng 55.2744, radius 150m, 09:00-18:00,
 *                     10 min tolerances, QR refresh 30s, Asia/Dubai
 *  - 3 departments, 4 designations
 *  - 8 employees:    emp1@company.com .. emp8@company.com / Employee@123
 */
const { connectDb, disconnectDb } = require('../config/db');
const User = require('../models/User');
const Department = require('../models/Department');
const Designation = require('../models/Designation');
const Attendance = require('../models/Attendance');
const AttendanceRequest = require('../models/AttendanceRequest');
const DocumentModel = require('../models/Document');
const OfficeSettings = require('../models/OfficeSettings');

const DEPARTMENTS = [
  { name: 'Engineering', description: 'Product development and technology' },
  { name: 'Human Resources', description: 'People operations and recruitment' },
  { name: 'Sales', description: 'Business development and client relations' },
];

const DESIGNATIONS = [
  { name: 'Software Engineer', description: 'Builds and maintains software' },
  { name: 'Senior Software Engineer', description: 'Leads technical implementation' },
  { name: 'HR Manager', description: 'Manages people operations' },
  { name: 'Sales Executive', description: 'Handles client accounts and deals' },
];

// [name, department index, designation index, phone, joiningDate]
const EMPLOYEES = [
  ['Aisha Khan', 0, 0, '+971500000001', '2024-02-05'],
  ['Omar Farooq', 0, 1, '+971500000002', '2023-11-20'],
  ['Priya Nair', 0, 0, '+971500000003', '2024-06-10'],
  ['Daniel Mathews', 0, 1, '+971500000004', '2023-08-01'],
  ['Fatima Al Mansoori', 1, 2, '+971500000005', '2022-04-18'],
  ['Ravi Sharma', 2, 3, '+971500000006', '2024-01-08'],
  ['Layla Hassan', 2, 3, '+971500000007', '2024-09-02'],
  ['John Peters', 1, 2, '+971500000008', '2023-03-27'],
];

async function seed() {
  await connectDb();
  console.log('Connected. Wiping existing data...');

  await Promise.all([
    User.deleteMany({}),
    Department.deleteMany({}),
    Designation.deleteMany({}),
    Attendance.deleteMany({}),
    AttendanceRequest.deleteMany({}),
    DocumentModel.deleteMany({}),
    OfficeSettings.deleteMany({}),
  ]);

  const settings = await OfficeSettings.create({
    latitude: 25.1972,
    longitude: 55.2744,
    radiusMeters: 150,
    workStartTime: '09:00',
    workEndTime: '18:00',
    lateToleranceMinutes: 10,
    earlyLeaveToleranceMinutes: 10,
    qrRefreshSeconds: 30,
    timezone: 'Asia/Dubai',
  });
  console.log(`Office settings created (${settings.timezone}, radius ${settings.radiusMeters}m)`);

  const departments = await Department.create(DEPARTMENTS);
  console.log(`Departments: ${departments.map((d) => d.name).join(', ')}`);

  const designations = await Designation.create(DESIGNATIONS);
  console.log(`Designations: ${designations.map((d) => d.name).join(', ')}`);

  const admin = await User.create({
    employeeId: 'ADM-0001',
    name: 'System Administrator',
    email: 'admin@company.com',
    password: 'Admin@123',
    role: 'admin',
    phone: '+971500000000',
    address: 'Head Office, Downtown Dubai',
    joiningDate: '2022-01-01',
  });
  console.log(`Admin: ${admin.email} / Admin@123`);

  for (let i = 0; i < EMPLOYEES.length; i += 1) {
    const [name, deptIdx, desigIdx, phone, joiningDate] = EMPLOYEES[i];
    const user = await User.create({
      employeeId: `EMP-${String(i + 1).padStart(4, '0')}`,
      name,
      email: `emp${i + 1}@company.com`,
      password: 'Employee@123',
      role: 'employee',
      department: departments[deptIdx]._id,
      designation: designations[desigIdx]._id,
      phone,
      address: `Apartment ${100 + i}, Business Bay, Dubai`,
      joiningDate,
    });
    console.log(`Employee: ${user.employeeId} ${user.email} / Employee@123 (${name})`);
  }

  console.log('Seed completed successfully.');
  await disconnectDb();
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  });
