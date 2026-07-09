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
      // vercel.json uses the legacy builds/routes format, which cannot set a
      // per-function maxDuration — Vercel's default (10s on Hobby) applies.
      // Keep all timeouts well under that so Express always gets to send a
      // JSON error before Vercel kills the lambda and returns HTML instead.
      serverSelectionTimeoutMS: 6000,
      connectTimeoutMS: 6000,
      socketTimeoutMS: 8000,
      maxPoolSize: 5,
      minPoolSize: 0,
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
