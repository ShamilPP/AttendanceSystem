const OfficeSettings = require('../models/OfficeSettings');
const { ok, asyncHandler } = require('../utils/respond');
const { issueQrToken } = require('../utils/qr');

// GET /qr/current — rotating encrypted QR payload for the admin panel to render
const current = asyncHandler(async (req, res) => {
  const settings = await OfficeSettings.getSingleton();
  const { qrData, issuedAt } = issueQrToken();
  ok(res, {
    qrData,
    expiresAt: new Date(issuedAt + settings.qrRefreshSeconds * 1000).toISOString(),
    refreshSeconds: settings.qrRefreshSeconds,
  });
});

module.exports = { current };
