const express = require('express');
const ctrl = require('../controllers/employeeController');
const { authenticate, requireRole } = require('../middleware/auth');
const { importUpload } = require('../middleware/upload');

const router = express.Router();

router.use(authenticate, requireRole('admin'));

router.get('/export', ctrl.exportEmployees);
router.post('/import', importUpload.single('file'), ctrl.importEmployees);
router.get('/', ctrl.list);
router.post('/', ctrl.create);
router.get('/:id', ctrl.getOne);
router.put('/:id', ctrl.update);
router.delete('/:id', ctrl.remove);

module.exports = router;
