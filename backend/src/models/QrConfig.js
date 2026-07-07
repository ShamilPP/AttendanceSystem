const mongoose = require('mongoose');
const { generateToken, buildQrData } = require('../utils/qr');

/**
 * Permanent (static) QR code singleton.
 * Stores the current token, version, the exact encrypted qrData string served
 * byte-identical on every read, and when it was generated.
 */
const qrConfigSchema = new mongoose.Schema(
  {
    token: { type: String, required: true },
    version: { type: Number, required: true, default: 1 },
    qrData: { type: String, required: true },
    generatedAt: { type: Date, required: true, default: Date.now },
  },
  { timestamps: true, toJSON: { versionKey: false } }
);

/** Mint a brand-new code at the given version. */
qrConfigSchema.statics.mint = function mint(version) {
  const token = generateToken();
  return {
    token,
    version,
    qrData: buildQrData(token, version),
    generatedAt: new Date(),
  };
};

/** Singleton accessor — lazily creates version 1 on first use. */
qrConfigSchema.statics.getSingleton = async function getSingleton() {
  let config = await this.findOne();
  if (!config) config = await this.create(this.mint(1));
  return config;
};

/** Regenerate: new token, version + 1, new qrData; invalidates the old code. */
qrConfigSchema.statics.regenerate = async function regenerate() {
  const config = await this.getSingleton();
  const next = this.mint(config.version + 1);
  config.token = next.token;
  config.version = next.version;
  config.qrData = next.qrData;
  config.generatedAt = next.generatedAt;
  await config.save();
  return config;
};

module.exports = mongoose.model('QrConfig', qrConfigSchema);
