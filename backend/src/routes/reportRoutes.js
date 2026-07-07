const express = require('express');
const ctrl = require('../controllers/reportController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate, requireRole('admin'));
router.get('/attendance', ctrl.attendanceReport);
router.get('/working-hours', ctrl.workingHoursReport);
router.get('/late-arrivals', ctrl.lateArrivalsReport);
router.get('/early-checkouts', ctrl.earlyCheckoutsReport);

module.exports = router;
