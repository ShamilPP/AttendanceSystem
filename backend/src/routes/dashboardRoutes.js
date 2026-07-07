const express = require('express');
const { stats, trends } = require('../controllers/dashboardController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate, requireRole('admin'));
router.get('/stats', stats);
router.get('/trends', trends);

module.exports = router;
