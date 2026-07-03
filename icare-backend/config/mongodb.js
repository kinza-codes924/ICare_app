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
      serverSelectionTimeoutMS: 10000, // 10s — covers Vercel cold starts
      connectTimeoutMS: 10000,
      socketTimeoutMS: 15000,
      maxPoolSize: 5,
      minPoolSize: 0,
      maxIdleTimeMS: 60000, // keep warm for 60s between requests
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

module.exports = { connectMongoDB };
