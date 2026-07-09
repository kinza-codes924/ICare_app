const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const Product = require('../models/Product');
const CartItem = require('../models/CartItem');
const PharmacyOrder = require('../models/PharmacyOrder');
const PharmacyProfile = require('../models/PharmacyProfile');
const { authMiddleware } = require('../middleware/auth');
const { sendToUser } = require('../services/notificationService');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── GET CART ─────────────────────────────────────────────────────────────────
router.get('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const cartItems = await CartItem.find({ user_id: userId }).sort({ createdAt: -1 }).lean();

    const productIds = cartItems.map(c => c.product_id);
    const products = await Product.find({ _id: { $in: productIds }, is_active: true }).lean();
    const pMap = {};
    products.forEach(p => { pMap[p._id.toString()] = p; });

    const pharmacyIds = [...new Set(products.map(p => p.pharmacy_id.toString()))];
    const pharmacies = await User.find({ _id: { $in: pharmacyIds.map(id => toId(id)) } }).lean();
    const phMap = {};
    pharmacies.forEach(p => { phMap[p._id.toString()] = p; });

    let total = 0;
    const cart = cartItems.map(c => {
      const p = pMap[c.product_id.toString()];
      if (!p) return null;
      total += (p.price || 0) * c.quantity;
      return {
        id: c._id.toString(),
        _id: c._id.toString(),
        quantity: c.quantity,
        createdAt: c.createdAt,
        product_id: p._id.toString(),
        name: p.name,
        description: p.description,
        price: p.price,
        stock_quantity: p.stock_quantity,
        requires_prescription: p.requires_prescription,
        medicine_category: p.medicine_category,
        generic_name: p.generic_name,
        pharmacy_name: phMap[p.pharmacy_id.toString()]?.username || phMap[p.pharmacy_id.toString()]?.name,
        pharmacy_id: p.pharmacy_id.toString(),
      };
    }).filter(Boolean);

    res.status(200).json({ success: true, cart, total: total.toFixed(2), count: cart.length });
  } catch (error) {
    console.error('Get cart error:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch cart' });
  }
});

// ─── ADD TO CART ──────────────────────────────────────────────────────────────
router.post('/add', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { productId, quantity, prescriptionId } = req.body;

    if (!productId || !quantity || quantity < 1) {
      return res.status(400).json({ success: false, message: 'Product ID and valid quantity are required' });
    }

    const product = await Product.findOne({ _id: toId(productId), is_active: true }).lean();
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    // Controlled/Vaccine check
    if (product.medicine_category === 'Controlled' || product.medicine_category === 'Vaccine') {
      if (!prescriptionId) {
        return res.status(400).json({
          success: false,
          message: 'This medicine can only be purchased online after consultation with our doctor. It is mandatory to have a consultation with our doctor.',
          requiresConsultation: true,
          medicineCategory: product.medicine_category,
        });
      }
    }

    // 30-unit cap
    if (!prescriptionId && quantity > 30) {
      return res.status(400).json({
        success: false,
        message: 'Maximum 30 units allowed per order without prescription. Please consult with our doctor for larger quantities.',
        maxQuantity: 30,
        requiresConsultation: true,
      });
    }

    if (product.stock_quantity < quantity) {
      return res.status(400).json({ success: false, message: 'Insufficient stock' });
    }

    const existing = await CartItem.findOne({ user_id: userId, product_id: toId(productId) });

    let cartItem;
    if (existing) {
      const newQuantity = existing.quantity + quantity;
      if (!prescriptionId && newQuantity > 30) {
        return res.status(400).json({
          success: false,
          message: 'Maximum 30 units allowed per order without prescription',
          maxQuantity: 30,
          currentQuantity: existing.quantity,
          requiresConsultation: true,
        });
      }
      if (product.stock_quantity < newQuantity) {
        return res.status(400).json({ success: false, message: 'Insufficient stock for requested quantity' });
      }
      existing.quantity = newQuantity;
      if (prescriptionId) existing.prescription_id = prescriptionId;
      await existing.save();
      cartItem = existing;
    } else {
      cartItem = await CartItem.create({
        user_id: userId,
        product_id: toId(productId),
        quantity,
        prescription_id: prescriptionId || null,
      });
    }

    res.status(200).json({ success: true, message: 'Item added to cart', cartItem: { ...cartItem.toObject(), _id: cartItem._id.toString() } });
  } catch (error) {
    console.error('Add to cart error:', error.name, error.message, error.code);
    // Duplicate key = item already in cart (race condition) — treat as success
    if (error.code === 11000) {
      return res.status(400).json({ success: false, message: 'Item already in cart' });
    }
    // Validation error
    if (error.name === 'ValidationError') {
      return res.status(400).json({ success: false, message: error.message });
    }
    res.status(500).json({ success: false, message: error.message || 'Failed to add item to cart' });
  }
});

// ─── UPDATE CART ITEM ─────────────────────────────────────────────────────────
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { quantity, prescriptionId } = req.body;

    if (!quantity || quantity < 1) {
      return res.status(400).json({ success: false, message: 'Valid quantity is required' });
    }

    const cartItem = await CartItem.findOne({ _id: toId(req.params.id), user_id: userId });
    if (!cartItem) {
      return res.status(404).json({ success: false, message: 'Cart item not found' });
    }

    const product = await Product.findById(cartItem.product_id).lean();

    if (!prescriptionId && quantity > 30) {
      return res.status(400).json({
        success: false,
        message: 'Maximum 30 units allowed per order without prescription',
        maxQuantity: 30,
        requiresConsultation: true,
      });
    }

    if (product && product.stock_quantity < quantity) {
      return res.status(400).json({ success: false, message: 'Insufficient stock' });
    }

    cartItem.quantity = quantity;
    await cartItem.save();

    res.status(200).json({ success: true, message: 'Cart updated', cartItem: { ...cartItem.toObject(), _id: cartItem._id.toString() } });
  } catch (error) {
    console.error('Update cart error:', error);
    res.status(500).json({ success: false, message: 'Failed to update cart' });
  }
});

// ─── REMOVE ITEM ──────────────────────────────────────────────────────────────
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const item = await CartItem.findOneAndDelete({ _id: toId(req.params.id), user_id: userId });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Cart item not found' });
    }
    res.status(200).json({ success: true, message: 'Item removed from cart' });
  } catch (error) {
    console.error('Remove from cart error:', error);
    res.status(500).json({ success: false, message: 'Failed to remove item' });
  }
});

// ─── CLEAR CART ───────────────────────────────────────────────────────────────
router.delete('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await CartItem.deleteMany({ user_id: toId(req.user.id) });
    res.status(200).json({ success: true, message: 'Cart cleared' });
  } catch (error) {
    console.error('Clear cart error:', error);
    res.status(500).json({ success: false, message: 'Failed to clear cart' });
  }
});

// ─── CHECKOUT ─────────────────────────────────────────────────────────────────
router.post('/checkout', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();

    const userId = toId(req.user.id);
    if (!userId) return res.status(400).json({ success: false, message: 'Invalid user ID in token' });

    const { deliveryAddress, pharmacyId } = req.body;
    if (!deliveryAddress || !String(deliveryAddress).trim()) {
      return res.status(400).json({ success: false, message: 'Delivery address is required' });
    }

    // 1. Load cart items
    const cartItems = await CartItem.find({ user_id: userId }).lean();
    if (!cartItems || cartItems.length === 0) {
      return res.status(400).json({ success: false, message: 'Cart is empty' });
    }

    // 2. Load products (no is_active filter — take whatever is in cart)
    const productIds = cartItems.map(c => c.product_id).filter(Boolean);
    const products = await Product.find({ _id: { $in: productIds } }).lean();
    const pMap = {};
    products.forEach(p => { pMap[String(p._id)] = p; });

    // 3. Build order items
    let totalAmount = 0;
    let resolvedPharmacyId = pharmacyId ? toId(pharmacyId) : null;
    const orderItems = [];

    for (const item of cartItems) {
      const pid = String(item.product_id || '');
      const product = pMap[pid];
      if (!product) {
        console.warn('Checkout: product not in DB for id:', pid);
        continue;
      }
      if (!resolvedPharmacyId && product.pharmacy_id) {
        resolvedPharmacyId = product.pharmacy_id;
      }
      const price = Number(product.price) || 0;
      const qty   = Number(item.quantity)  || 1;
      totalAmount += price * qty;
      orderItems.push({
        product_id:   product._id,
        product_name: String(product.name || product.productName || 'Medicine'),
        generic_name: String(product.generic_name || ''),
        quantity: qty,
        price,
      });
    }

    if (orderItems.length === 0) {
      return res.status(400).json({ success: false, message: 'Products in your cart are no longer available. Please refresh and try again.' });
    }

    // 4. If no pharmacy found from products, pick the first active pharmacy user
    if (!resolvedPharmacyId) {
      const anyPharmacy = await User.findOne({ role: { $in: ['Pharmacy', 'pharmacy'] } }).lean().catch(() => null);
      if (anyPharmacy) resolvedPharmacyId = anyPharmacy._id;
    }

    // Pick up prescription_id from any cart item that has one
    const prescriptionId = cartItems.find(c => c.prescription_id)?.prescription_id || undefined;

    // Fetch pharmacy delivery fee
    let deliveryFee = 0;
    if (resolvedPharmacyId) {
      const pharmProfile = await PharmacyProfile.findOne({ user_id: resolvedPharmacyId }).lean().catch(() => null);
      deliveryFee = Number(pharmProfile?.delivery_fee) || 0;
    }

    // 5. Create order
    const orderPayload = {
      patient_id:       userId,
      pharmacy_id:      resolvedPharmacyId || null,
      total_amount:     totalAmount + deliveryFee,
      delivery_fee:     deliveryFee,
      delivery_address: String(deliveryAddress).trim(),
      status:           'pending',
      order_number:     `ORD-${Date.now()}-${Math.random().toString(36).substr(2,5).toUpperCase()}`,
      items:            orderItems,
      ...(prescriptionId ? { prescription_id: prescriptionId } : {}),
    };

    const order = await PharmacyOrder.create(orderPayload);

    // 5. Decrement stock (best-effort, never block the response)
    for (const item of cartItems) {
      Product.findByIdAndUpdate(item.product_id, { $inc: { stock_quantity: -Number(item.quantity) } })
        .catch(e => console.error('Stock update error:', e.message));
    }

    // 6. Clear cart
    await CartItem.deleteMany({ user_id: userId });

    // 7. Notify pharmacy about new order (best-effort)
    if (resolvedPharmacyId) {
      sendToUser(resolvedPharmacyId, {
        title: '🛒 New Order Received',
        body: `Order ${order.order_number} has been placed. Tap to review.`,
        data: { orderId: String(order._id), type: 'new_order' },
        type: 'new_order',
      }).catch(() => {});
    }

    return res.status(201).json({
      success: true,
      message: 'Order placed successfully',
      order: {
        _id:          String(order._id),
        order_number: order.order_number,
        total_amount: order.total_amount,
        status:       order.status,
        items:        orderItems,
      },
    });
  } catch (error) {
    const errName = error.name || 'Error';
    const errMsg  = error.message || 'Failed to place order';
    console.error('Checkout error:', errName, '-', errMsg, '-', JSON.stringify(error.errors || {}));
    return res.status(500).json({ success: false, message: errMsg, type: errName });
  }
});

module.exports = router;
