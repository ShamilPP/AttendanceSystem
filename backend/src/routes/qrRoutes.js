const express = require('express');
const { current } = require('../controllers/qrController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/current', authenticate, requireRole('admin'), current);

module.exports = router;
