const express = require('express');
const ctrl = require('./scenario.controller');
const auth = require('../../middleware/auth.middleware');
const coverUpload = require('./cover.upload');
const interactionRoutes = require('../interaction/interaction.routes');

const router = express.Router();

router.get('/', ctrl.list);
router.get('/mine', auth, ctrl.listMine);
router.post('/suggest-plot-choices', auth, ctrl.suggestPlotChoices);
router.post('/suggest-plot-points', auth, ctrl.suggestPlotPoints);
router.post('/', auth, ctrl.create);
router.get('/:id', ctrl.getOne);
router.patch('/:id', auth, ctrl.update);
router.put('/:id/full', auth, ctrl.updateFull);
router.post('/:id/publish', auth, ctrl.publish);
router.post('/:id/cover', auth, coverUpload.single('cover'), ctrl.uploadCover);
router.delete('/:id', auth, ctrl.remove);

router.use('/:storyId', interactionRoutes);

module.exports = router;