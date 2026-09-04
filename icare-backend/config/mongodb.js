const mongoose = require('mongoose');
require('dotenv').config();

// Single in-flight promise — prevents multiple concurrent cold-start connections
let _connectionPromise = null;

const connectMongoDB = async () => {
  // Already connected — reuse existing connection
  if (mongoose.connection.readyState === 1) return;

  // A connection attempt is already in-flight — wait for it
  if (_connectionPromise) return _connectionPromise;

  const uri = (process.env.MONGO_URI || process.env.MONGODB_URI || '').trim();
  if (!uri) {
    const err = new Error('MONGO_URI or MONGODB_URI environment variable is not set');
    console.error('❌ MongoDB connection error:', err.message);
    throw err;
  }

  _connectionPromise = mongoose
    .connect(uri, {
      // These were sized for Vercel's 10s Hobby lambda cap, so every timeout
      // sat below it. The app now runs as a long-lived PM2 process on its own
      // server, where no such cap exists — and the old 8s socket timeout was
      // cutting off real queries mid-flight, surfacing as
      // MongoNetworkTimeoutError and blanket 500s on /get_all_doctors and
      // /getAppointments. Sized for a persistent server instead.
      serverSelectionTimeoutMS: 15000,
      connectTimeoutMS: 15000,
      socketTimeoutMS: 45000,
      maxPoolSize: 10,
      minPoolSize: 1,
      maxIdleTimeMS: 60000, // keep warm for 60s between requests
      retryWrites: true,
      retryReads: true,
    })
    .then(() => {
      console.log('✅ MongoDB connected');
    })
    .catch((err) => {
      _connectionPromise = null; // reset so next request retries
      console.error('❌ MongoDB connection error:', err.message);
      throw err;
    });

  return _connectionPromise;
};

// Reset the in-flight promise when Atlas drops an idle connection so the
// next request triggers a fresh connect() instead of returning the old
// resolved promise (which would bypass reconnection).
mongoose.connection.on('disconnected', () => {
  _connectionPromise = null;
  console.log('⚠️ MongoDB disconnected — will reconnect on next request');
});

mongoose.connection.on('error', () => {
  _connectionPromise = null;
});

module.exports = { connectMongoDB };
