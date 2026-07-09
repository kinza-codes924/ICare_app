const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');

// Health check / DB status
router.get('/status', async (req, res) => {
  try {
    await connectMongoDB();
    res.json({ success: true, message: 'MongoDB connected', database: 'MongoDB' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Database connection failed', error: error.message });
  }
});

// One-time migration: drop the bad orderNumber_1 unique index and fix null values
router.post('/fix-order-index', async (req, res) => {
  try {
    await connectMongoDB();
    const db = mongoose.connection.db;
    const col = db.collection('pharmacyorders');

    // List existing indexes
    const indexes = await col.indexes();
    const hasIndex = indexes.some(i => i.name === 'orderNumber_1');

    if (hasIndex) {
      await col.dropIndex('orderNumber_1');
    }

    // Backfill orderNumber for any docs that have order_number but no orderNumber
    const result = await col.updateMany(
      { order_number: { $exists: true, $ne: null }, orderNumber: { $exists: false } },
      [{ $set: { orderNumber: '$order_number' } }]
    );

    res.json({
      success: true,
      indexDropped: hasIndex,
      docsBackfilled: result.modifiedCount,
      message: 'Migration complete',
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/init', async (req, res) => {
  res.json({ success: true, message: 'MongoDB does not require table initialization. Collections are created automatically.' });
});

router.all('/{*path}', (req, res) => {
  res.json({ success: true, message: 'Database API (MongoDB)' });
});

module.exports = router;
