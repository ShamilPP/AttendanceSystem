const express = require('express');
const { current, regenerate } = require('../controllers/qrController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/current', authenticate, requireRole('admin'), current);
router.post('/regenerate', authenticate, requireRole('admin'), regenerate);

module.exports = router;
