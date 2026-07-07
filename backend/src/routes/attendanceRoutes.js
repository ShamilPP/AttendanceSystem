const express = require('express');
const attendance = require('../controllers/attendanceController');
const requests = require('../controllers/requestController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);

// Employee endpoints
router.post('/scan', requireRole('employee'), attendance.scan);
router.get('/today', requireRole('employee'), attendance.today);
router.get('/history', requireRole('employee'), attendance.history);
router.get('/summary', requireRole('employee'), attendance.summary);
router.post('/requests', requireRole('employee'), requests.createRequest);
router.get('/requests/me', requireRole('employee'), requests.myRequests);

// Admin endpoints
router.get('/requests', requireRole('admin'), requests.listRequests);
router.put('/requests/:id', requireRole('admin'), requests.reviewRequest);
router.get('/live', requireRole('admin'), attendance.live);
router.get('/logs', requireRole('admin'), attendance.logs);
router.post('/manual', requireRole('admin'), attendance.manual);
router.get('/missing-checkouts', requireRole('admin'), attendance.missingCheckouts);
router.put('/:id/correct', requireRole('admin'), attendance.correct);
router.put('/:id/resolve-checkout', requireRole('admin'), attendance.resolveCheckout);

module.exports = router;
