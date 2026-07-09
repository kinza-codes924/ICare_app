const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const Product = require('../models/Product');
const PharmacyProfile = require('../models/PharmacyProfile');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── GET ALL PRODUCTS (public) ────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    await connectMongoDB();
    const { category, search, pharmacy_id } = req.query;
    const query = { is_active: true };
    if (category) query.category = category;
    if (pharmacy_id) query.pharmacy_id = toId(pharmacy_id);

    let products = await Product.find(query).sort({ createdAt: -1 }).lean();

    if (search) {
      const s = search.toLowerCase();
      products = products.filter(p => p.name?.toLowerCase().includes(s) || p.description?.toLowerCase().includes(s));
    }

    // Enrich with pharmacy info
    const pharmacyIds = [...new Set(products.map(p => p.pharmacy_id.toString()))];
    const pharmacies = await User.find({ _id: { $in: pharmacyIds.map(id => toId(id)) } }).lean();
    const pMap = {};
    pharmacies.forEach(p => { pMap[p._id.toString()] = p; });

    const result = products.map(p => ({
      ...p,
      _id: p._id.toString(),
      pharmacy_name: pMap[p.pharmacy_id.toString()]?.username || pMap[p.pharmacy_id.toString()]?.name,
    }));

    res.status(200).json({ success: true, products: result, count: result.length });
  } catch (error) {
    console.error('Get products error:', error);
    res.status(200).json({ success: true, products: [], count: 0 });
  }
});

// ─── GET PRODUCT BY ID ────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    await connectMongoDB();
    const product = await Product.findOne({ _id: toId(req.params.id), is_active: true }).lean();
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    const [pharmacyUser, pharmacyProfile] = await Promise.all([
      User.findById(product.pharmacy_id).lean(),
      PharmacyProfile.findOne({ user_id: product.pharmacy_id }).lean(),
    ]);

    res.status(200).json({
      success: true,
      product: {
        ...product,
        _id: product._id.toString(),
        pharmacy_name: pharmacyUser?.username || pharmacyUser?.name,
        pharmacy_full_name: pharmacyProfile?.pharmacy_name,
        delivery_available: pharmacyProfile?.delivery_available,
      },
    });
  } catch (error) {
    console.error('Get product error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch product' });
  }
});

// ─── CREATE PRODUCT ───────────────────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role !== 'pharmacy') {
      return res.status(403).json({ success: false, message: 'Only pharmacies can add products' });
    }

    const { name, genericName, description, category, medicineCategory, price, stockQuantity, imageUrl, manufacturer, requiresPrescription } = req.body;

    if (!name || !price) {
      return res.status(400).json({ success: false, message: 'Name and price are required' });
    }

    const product = await Product.create({
      pharmacy_id: toId(req.user.id),
      name,
      generic_name: genericName || null,
      description: description || '',
      category: category || 'general',
      medicine_category: medicineCategory || 'OTC',
      price,
      stock_quantity: stockQuantity || 0,
      manufacturer: manufacturer || '',
      requires_prescription: requiresPrescription || false,
    });

    res.status(201).json({ success: true, message: 'Product added successfully', product: { ...product.toObject(), _id: product._id.toString() } });
  } catch (error) {
    console.error('Create product error:', error);
    res.status(500).json({ success: false, message: 'Failed to add product' });
  }
});

// ─── UPDATE PRODUCT ───────────────────────────────────────────────────────────
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role !== 'pharmacy') {
      return res.status(403).json({ success: false, message: 'Only pharmacies can update products' });
    }

    const pharmacyId = toId(req.user.id);
    const product = await Product.findOne({ _id: toId(req.params.id), pharmacy_id: pharmacyId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found or access denied' });
    }

    const { name, genericName, description, category, medicineCategory, price, stockQuantity, imageUrl, manufacturer, requiresPrescription, isActive } = req.body;

    if (name !== undefined) product.name = name;
    if (genericName !== undefined) product.generic_name = genericName;
    if (description !== undefined) product.description = description;
    if (category !== undefined) product.category = category;
    if (medicineCategory !== undefined) product.medicine_category = medicineCategory;
    if (price !== undefined) product.price = price;
    if (stockQuantity !== undefined) product.stock_quantity = stockQuantity;
    if (manufacturer !== undefined) product.manufacturer = manufacturer;
    if (requiresPrescription !== undefined) product.requires_prescription = requiresPrescription;
    if (isActive !== undefined) product.is_active = isActive;

    await product.save();

    res.status(200).json({ success: true, message: 'Product updated successfully', product: { ...product.toObject(), _id: product._id.toString() } });
  } catch (error) {
    console.error('Update product error:', error);
    res.status(500).json({ success: false, message: 'Failed to update product' });
  }
});

// ─── DELETE PRODUCT ───────────────────────────────────────────────────────────
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role !== 'pharmacy') {
      return res.status(403).json({ success: false, message: 'Only pharmacies can delete products' });
    }

    const pharmacyId = toId(req.user.id);
    const product = await Product.findOneAndUpdate(
      { _id: toId(req.params.id), pharmacy_id: pharmacyId },
      { is_active: false },
      { new: true }
    );

    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found or access denied' });
    }

    res.status(200).json({ success: true, message: 'Product deleted successfully' });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete product' });
  }
});

module.exports = router;
