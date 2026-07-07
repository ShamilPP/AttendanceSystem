const express = require('express');
const { departments, designations } = require('../controllers/catalogController');
const { authenticate, requireRole } = require('../middleware/auth');

function makeRouter(ctrl) {
  const router = express.Router();
  router.use(authenticate);
  router.get('/', ctrl.list); // any authenticated role
  router.post('/', requireRole('admin'), ctrl.create);
  router.put('/:id', requireRole('admin'), ctrl.update);
  router.delete('/:id', requireRole('admin'), ctrl.remove);
  return router;
}

module.exports = {
  departmentRouter: makeRouter(departments),
  designationRouter: makeRouter(designations),
};
