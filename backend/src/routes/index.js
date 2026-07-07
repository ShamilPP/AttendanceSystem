const express = require('express');
const authRoutes = require('./authRoutes');
const employeeRoutes = require('./employeeRoutes');
const { departmentRouter, designationRouter } = require('./catalogRoutes');
const officeSettingsRoutes = require('./officeSettingsRoutes');
const qrRoutes = require('./qrRoutes');
const attendanceRoutes = require('./attendanceRoutes');
const dashboardRoutes = require('./dashboardRoutes');
const reportRoutes = require('./reportRoutes');
const documentRoutes = require('./documentRoutes');

const router = express.Router();

router.get('/health', (req, res) => res.json({ success: true, data: { status: 'ok' } }));

router.use('/auth', authRoutes);
router.use('/employees', employeeRoutes);
router.use('/departments', departmentRouter);
router.use('/designations', designationRouter);
router.use('/office-settings', officeSettingsRoutes);
router.use('/qr', qrRoutes);
router.use('/attendance', attendanceRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/reports', reportRoutes);
router.use('/documents', documentRoutes);

module.exports = router;
