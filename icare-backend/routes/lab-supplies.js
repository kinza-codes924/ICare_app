const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');

// ─── STUB ENDPOINTS FOR LAB SUPPLIES ─────────────────────────────────────────
// These are placeholder endpoints until the full inventory system is implemented

// Get all supplies
router.get('/', authMiddleware, async (req, res) => {
  try {
    // Return empty array for now
    res.json({ success: true, supplies: [] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to fetch supplies' });
  }
});

// Get low stock alerts
router.get('/low-stock', authMiddleware, async (req, res) => {
  try {
    // Return zero count for now
    res.json({ success: true, count: 0, alerts: [] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to fetch low stock alerts' });
  }
});

// Add supply
router.post('/', authMiddleware, async (req, res) => {
  try {
    // Stub: just return success
    res.status(201).json({ 
      success: true, 
      message: 'Supply added (stub)', 
      supply: { _id: 'stub-id', ...req.body } 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to add supply' });
  }
});

// Update stock
router.put('/:supplyId/stock', authMiddleware, async (req, res) => {
  try {
    // Stub: just return success
    res.json({ 
      success: true, 
      message: 'Stock updated (stub)', 
      supply: { _id: req.params.supplyId, ...req.body } 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to update stock' });
  }
});

// Delete supply
router.delete('/:supplyId', authMiddleware, async (req, res) => {
  try {
    // Stub: just return success
    res.json({ success: true, message: 'Supply deleted (stub)' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Failed to delete supply' });
  }
});

module.exports = router;
