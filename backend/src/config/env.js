const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const env = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: parseInt(process.env.PORT, 10) || 5000,
  MONGODB_URI: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/attendance_system',
  JWT_SECRET: process.env.JWT_SECRET,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  QR_SECRET: process.env.QR_SECRET,
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
  UPLOADS_DIR: path.resolve(__dirname, '../../uploads'),
};

if (!env.JWT_SECRET) {
  throw new Error('JWT_SECRET is not set. Copy .env.example to .env and fill it in.');
}
if (!env.QR_SECRET || Buffer.from(env.QR_SECRET, 'base64').length !== 32) {
  throw new Error('QR_SECRET must be a base64-encoded 32-byte key (e.g. `openssl rand -base64 32`).');
}

module.exports = env;
