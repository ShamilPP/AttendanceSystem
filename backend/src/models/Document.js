const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema(
  {
    employee: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: ['ID_PROOF', 'COMPANY_ID', 'OTHER'], required: true },
    name: { type: String, required: true, trim: true },
    fileName: { type: String, required: true }, // original upload name
    storedName: { type: String, required: true }, // name on disk under uploads/
    mimeType: { type: String, required: true },
    size: { type: Number, required: true },
    uploadedAt: { type: Date, default: Date.now },
  },
  {
    toJSON: {
      versionKey: false,
      transform(doc, ret) {
        delete ret.storedName; // internal
        return ret;
      },
    },
  }
);

documentSchema.index({ employee: 1, uploadedAt: -1 });

module.exports = mongoose.model('Document', documentSchema);
