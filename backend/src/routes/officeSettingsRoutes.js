const express = require('express');
const { getSettings, updateSettings } = require('../controllers/officeSettingsController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);
router.get('/', getSettings);
router.put('/', requireRole('admin'), updateSettings);

module.exports = router;
