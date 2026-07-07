const express = require('express');
const ctrl = require('../controllers/documentController');
const { authenticate, requireRole } = require('../middleware/auth');
const { documentUpload } = require('../middleware/upload');

const router = express.Router();

router.use(authenticate);

router.post('/', requireRole('employee'), documentUpload.single('file'), ctrl.upload);
router.get('/me', requireRole('employee'), ctrl.listMine);
router.get('/', requireRole('admin'), ctrl.listAll);
router.get('/:id/download', ctrl.download); // owner or admin (checked in controller)
router.delete('/:id', ctrl.remove); // owner or admin (checked in controller)

module.exports = router;
