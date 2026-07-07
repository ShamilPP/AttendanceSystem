const http = require('http');
const env = require('./config/env');
const { connectDb } = require('./config/db');
const app = require('./app');

function listen(host) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(app);
    server.once('error', reject);
    server.listen(env.PORT, host, () => resolve(server));
  });
}

async function main() {
  await connectDb();
  // eslint-disable-next-line no-console
  console.log(`MongoDB connected: ${env.MONGODB_URI}`);

  const servers = [];
  try {
    // Preferred: dual-stack wildcard.
    servers.push(await listen(undefined));
  } catch (err) {
    if (err.code !== 'EADDRINUSE') throw err;
    // Something else (e.g. macOS AirPlay Receiver) holds the wildcard on this
    // port. Bind the loopback addresses explicitly so localhost still works.
    // eslint-disable-next-line no-console
    console.warn(`Wildcard :${env.PORT} is taken; binding loopback addresses explicitly.`);
    servers.push(await listen('127.0.0.1'));
    try {
      servers.push(await listen('::1'));
    } catch {
      // IPv6 loopback unavailable — IPv4 is enough.
    }
  }

  // eslint-disable-next-line no-console
  console.log(`Attendance API listening on http://localhost:${env.PORT} (base /api/v1)`);

  const shutdown = () => {
    let remaining = servers.length;
    for (const server of servers) {
      server.close(() => {
        remaining -= 1;
        if (remaining <= 0) process.exit(0);
      });
    }
    setTimeout(() => process.exit(0), 3000).unref();
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start server:', err);
  process.exit(1);
});
