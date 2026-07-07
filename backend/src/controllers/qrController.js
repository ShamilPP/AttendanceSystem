const QrConfig = require('../models/QrConfig');
const { ok, asyncHandler } = require('../utils/respond');

function present(config) {
  return {
    qrData: config.qrData,
    version: config.version,
    generatedAt: config.generatedAt,
  };
}

// GET /qr/current — permanent encrypted QR payload (lazily created on first use)
const current = asyncHandler(async (req, res) => {
  const config = await QrConfig.getSingleton();
  ok(res, present(config));
});

// POST /qr/regenerate — mint a new code, invalidating the previous one
const regenerate = asyncHandler(async (req, res) => {
  const config = await QrConfig.regenerate();
  ok(res, present(config));
});

module.exports = { current, regenerate };
