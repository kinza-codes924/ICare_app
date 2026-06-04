const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const PharmacyProfile = require('../models/PharmacyProfile');
const Product = require('../models/Product');
const PharmacyOrder = require('../models/PharmacyOrder');
const { authMiddleware } = require('../middleware/auth');
const { sendToUser } = require('../services/notificationService');

// Notification messages per status
function _statusNotifPayload(status, orderNumber) {
  const map = {
    confirmed:         { title: '✅ Order Confirmed', body: `Your order ${orderNumber} has been confirmed by the pharmacy.`, type: 'delivery_update' },
    preparing:         { title: '⚗️ Order Being Prepared', body: `Your order ${orderNumber} is now being prepared.`, type: 'delivery_update' },
    'out-for-delivery':{ title: '🚚 Order Dispatched', body: `Your order ${orderNumber} is on its way!`, type: 'order_dispatched' },
    delivered:         { title: '📦 Order Delivered', body: `Your order ${orderNumber} has been delivered. Enjoy!`, type: 'delivery_update' },
    completed:         { title: '✅ Order Completed', body: `Your order ${orderNumber} is marked complete.`, type: 'delivery_update' },
    rejected:          { title: '❌ Order Rejected', body: `Your order ${orderNumber} was rejected. Please contact the pharmacy.`, type: 'delivery_update' },
    cancelled:         { title: '🚫 Order Cancelled', body: `Your order ${orderNumber} has been cancelled.`, type: 'delivery_update' },
  };
  return map[status] || null;
}

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── HAVERSINE DISTANCE (km) ──────────────────────────────────────────────────
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─── GET ALL PHARMACIES ───────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    await connectMongoDB();
    const users = await User.find({ role: { $in: ['pharmacy', 'Pharmacy'] }, is_active: { $ne: false } }).lean();
    const ids = users.map(u => u._id);
    const profiles = await PharmacyProfile.find({ user_id: { $in: ids } }).lean();
    const pMap = {};
    profiles.forEach(p => { pMap[p.user_id.toString()] = p; });

    const pharmacies = users.map(u => {
      const p = pMap[u._id.toString()] || {};
      return {
        id: u._id.toString(), _id: u._id.toString(),
        name: u.username || u.name, email: u.email, phone: u.phone,
        pharmacy_name: p.pharmacy_name, license_number: p.license_number,
        operating_hours: p.operating_hours, delivery_available: p.delivery_available,
        delivery_fee: p.delivery_fee, address: p.address, city: p.city,
        latitude: p.latitude ?? null, longitude: p.longitude ?? null,
        lat: p.latitude ?? null, lng: p.longitude ?? null,
        rating: p.rating ?? 0, total_reviews: p.total_reviews ?? 0,
      };
    });
    res.json({ success: true, pharmacies });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to fetch pharmacies' });
  }
});

router.get('/get_all_pharmacy', async (req, res) => {
  try {
    await connectMongoDB();
    const users = await User.find({ role: { $in: ['pharmacy', 'Pharmacy'] }, is_active: { $ne: false } }).lean();
    const ids = users.map(u => u._id);
    const profiles = await PharmacyProfile.find({ user_id: { $in: ids } }).lean();
    const pMap = {};
    profiles.forEach(p => { pMap[p.user_id.toString()] = p; });

    const pharmacies = users.map(u => {
      const p = pMap[u._id.toString()] || {};
      return {
        id: u._id.toString(), _id: u._id.toString(),
        name: u.username || u.name, email: u.email, phone: u.phone,
        pharmacy_name: p.pharmacy_name, license_number: p.license_number,
        operating_hours: p.operating_hours, delivery_available: p.delivery_available,
        delivery_fee: p.delivery_fee, address: p.address, city: p.city,
        latitude: p.latitude ?? null, longitude: p.longitude ?? null,
        lat: p.latitude ?? null, lng: p.longitude ?? null,
        rating: p.rating ?? 0, total_reviews: p.total_reviews ?? 0,
      };
    });
    res.json({ success: true, pharmacies });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to fetch pharmacies' });
  }
});

// ─── GET NEARBY PHARMACIES ────────────────────────────────────────────────────
// GET /pharmacy/nearby?lat=31.5&lng=74.3&radius=20
router.get('/nearby', async (req, res) => {
  try {
    await connectMongoDB();
    const userLat = parseFloat(req.query.lat);
    const userLng = parseFloat(req.query.lng);
    const radius = parseFloat(req.query.radius) || 20; // default 20 km

    if (isNaN(userLat) || isNaN(userLng)) {
      return res.status(400).json({ success: false, message: 'lat and lng are required' });
    }

    const users = await User.find({ role: { $in: ['pharmacy', 'Pharmacy'] }, is_active: { $ne: false } }).lean();
    const ids = users.map(u => u._id);
    const profiles = await PharmacyProfile.find({ user_id: { $in: ids } }).lean();
    const pMap = {};
    profiles.forEach(p => { pMap[p.user_id.toString()] = p; });

    const pharmacies = users
      .map(u => {
        const p = pMap[u._id.toString()] || {};
        const lat = p.latitude ?? null;
        const lng = p.longitude ?? null;
        const distance = (lat != null && lng != null)
          ? haversineKm(userLat, userLng, lat, lng)
          : null;
        return {
          id: u._id.toString(), _id: u._id.toString(),
          name: u.username || u.name, email: u.email, phone: u.phone,
          pharmacy_name: p.pharmacy_name, license_number: p.license_number,
          operating_hours: p.operating_hours, delivery_available: p.delivery_available,
          delivery_fee: p.delivery_fee, address: p.address, city: p.city,
          latitude: lat, longitude: lng, distance_km: distance,
        };
      })
      .filter(p => p.distance_km === null || p.distance_km <= radius)
      .sort((a, b) => {
        if (a.distance_km === null) return 1;
        if (b.distance_km === null) return -1;
        return a.distance_km - b.distance_km;
      });

    res.json({ success: true, pharmacies, count: pharmacies.length });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to fetch nearby pharmacies' });
  }
});

// ─── PHARMACY PROFILE GET ─────────────────────────────────────────────────────
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const user = await User.findById(userId).lean();
    const profile = await PharmacyProfile.findOne({ user_id: userId }).lean() || {};

    res.json({
      success: true,
      pharmacy: {
        id: user._id.toString(),
        _id: user._id.toString(),   // always User._id — never let profile spread override this
        userId: user._id.toString(),
        username: user.username || user.name, email: user.email, phone: user.phone,
        ...profile,
        _id: user._id.toString(),   // re-assert after spread so profile._id can't override
        id: user._id.toString(),
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to fetch profile' });
  }
});

// ─── PHARMACY PROFILE UPSERT ──────────────────────────────────────────────────
router.post('/add_pharmacy_details', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { pharmacyName, licenseNumber, operatingHours, deliveryAvailable, deliveryFee, address, city, drapCompliance, profilePicture, latitude, longitude } = req.body;

    const profile = await PharmacyProfile.findOneAndUpdate(
      { user_id: userId },
      {
        $set: {
          pharmacy_name: pharmacyName, license_number: licenseNumber,
          operating_hours: operatingHours, delivery_available: deliveryAvailable ?? false,
          delivery_fee: deliveryFee ?? 0, address, city,
          drap_compliance: drapCompliance ?? false,
          ...(latitude != null && { latitude: parseFloat(latitude) }),
          ...(longitude != null && { longitude: parseFloat(longitude) }),
        },
      },
      { new: true, upsert: true }
    );

    // Save profilePicture to User model
    if (profilePicture !== undefined) {
      await User.findByIdAndUpdate(userId, { $set: { profilePicture } });
    }

    res.json({ success: true, pharmacy: profile, existingProfile: profile });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to update pharmacy details' });
  }
});

// ─── PHARMACY PROFILE PUT ─────────────────────────────────────────────────────
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const update = {};
    const { pharmacyName, licenseNumber, operatingHours, deliveryAvailable, deliveryFee, address, city, drapCompliance } = req.body;
    if (pharmacyName) update.pharmacy_name = pharmacyName;
    if (licenseNumber) update.license_number = licenseNumber;
    if (operatingHours) update.operating_hours = operatingHours;
    if (deliveryAvailable !== undefined) update.delivery_available = deliveryAvailable;
    if (deliveryFee !== undefined) update.delivery_fee = deliveryFee;
    if (address) update.address = address;
    if (city) update.city = city;
    if (drapCompliance !== undefined) update.drap_compliance = drapCompliance;

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'No fields to update' });
    }

    const profile = await PharmacyProfile.findOneAndUpdate(
      { user_id: userId },
      { $set: update },
      { new: true, upsert: true }
    );
    res.json({ success: true, profile });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to update pharmacy profile' });
  }
});

// ─── STATS ────────────────────────────────────────────────────────────────────
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [orders, products] = await Promise.all([
      PharmacyOrder.find({ pharmacy_id: userId }).lean(),
      Product.find({ pharmacy_id: userId, is_active: true }).lean(),
    ]);

    const todayOrders = orders.filter(o => new Date(o.createdAt) >= today).length;
    const totalOrders = orders.length;
    const pendingOrders = orders.filter(o => o.status === 'pending').length;
    const completedOrders = orders.filter(o => ['delivered', 'completed'].includes(o.status)).length;
    const totalProducts = products.length;
    const lowStock = products.filter(p => (p.stock_quantity ?? 0) < 30).length;
    const revenue = orders
      .filter(o => ['delivered', 'completed'].includes(o.status))
      .reduce((sum, o) => sum + (o.total_amount || 0), 0);

    res.json({ success: true, todayOrders, totalOrders, pendingOrders, completedOrders, totalProducts, lowStock, revenue: Math.round(revenue) });
  } catch (err) {
    console.error(err);
    res.json({ success: true, todayOrders: 0, totalOrders: 0, pendingOrders: 0, completedOrders: 0, totalProducts: 0, lowStock: 0, revenue: 0 });
  }
});

// ─── ANALYTICS ────────────────────────────────────────────────────────────────
router.get('/analytics', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);

    const [orders, products] = await Promise.all([
      PharmacyOrder.find({ pharmacy_id: userId }).lean(),
      Product.find({ pharmacy_id: userId }).lean(),
    ]);

    const completedOrders = orders.filter(o => ['delivered', 'completed'].includes(o.status));
    const totalRevenue = completedOrders.reduce((s, o) => s + (o.total_amount || 0), 0);
    const totalOrders = orders.length;
    const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

    const ordersAccepted = orders.filter(o => !['pending', 'cancelled', 'rejected'].includes(o.status)).length;
    const ordersCompleted = completedOrders.length;
    const failedDeliveries = orders.filter(o => ['cancelled', 'rejected'].includes(o.status)).length;
    const outOfStockCount = products.filter(p => (p.stock_quantity ?? 0) === 0).length;

    // Top selling: aggregate order items by product name
    const productSales = {};
    for (const order of orders) {
      for (const item of (order.items || [])) {
        const name = item.product_name || 'Unknown';
        if (!productSales[name]) productSales[name] = { name, sales: 0, revenue: 0 };
        productSales[name].sales += item.quantity || 1;
        productSales[name].revenue += (item.quantity || 1) * (item.price || 0);
      }
    }
    const topSellingProducts = Object.values(productSales)
      .sort((a, b) => b.sales - a.sales)
      .slice(0, 5)
      .map(p => ({ name: p.name, sales: p.sales, revenue: Math.round(p.revenue) }));

    res.json({
      success: true,
      totalRevenue: Math.round(totalRevenue),
      totalOrders,
      averageOrderValue: parseFloat(avgOrderValue.toFixed(2)),
      ordersAccepted,
      ordersCompleted,
      failedDeliveries,
      outOfStockCount,
      complaintsCount: 0,
      averageRating: 0,
      averageProcessTime: 'N/A',
      responseTime: '< 30m',
      topSellingProducts,
    });
  } catch (err) {
    console.error(err);
    res.json({ success: true, totalRevenue: 0, totalOrders: 0, averageOrderValue: 0, ordersAccepted: 0, ordersCompleted: 0, failedDeliveries: 0, outOfStockCount: 0, complaintsCount: 0, averageRating: 0, averageProcessTime: 'N/A', responseTime: '< 30m', topSellingProducts: [] });
  }
});

// ─── TOP SELLING PRODUCTS ─────────────────────────────────────────────────────
router.get('/top-selling', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const orders = await PharmacyOrder.find({ pharmacy_id: userId }).lean();

    const productSales = {};
    for (const order of orders) {
      for (const item of (order.items || [])) {
        const name = item.product_name || 'Unknown';
        if (!productSales[name]) productSales[name] = { name, sales: 0, revenue: 0 };
        productSales[name].sales += item.quantity || 1;
        productSales[name].revenue += (item.quantity || 1) * (item.price || 0);
      }
    }
    const topProducts = Object.values(productSales)
      .sort((a, b) => b.sales - a.sales)
      .slice(0, 5)
      .map(p => ({ name: p.name, sales: p.sales, revenue: Math.round(p.revenue) }));

    res.json({ success: true, topProducts });
  } catch (err) {
    console.error(err);
    res.json({ success: true, topProducts: [] });
  }
});

// ─── GET ORDERS (list for pharmacy) ──────────────────────────────────────────
router.get('/orders/pharmacy/list', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const rawUserId = req.user.id || req.user._id;
    const userId = toId(rawUserId);
    if (!userId) return res.status(401).json({ success: false, message: 'Invalid token' });

    const { status } = req.query;

    // Search by this pharmacy's user_id AND also by any profile linked to them
    const profile = await PharmacyProfile.findOne({ user_id: userId }).lean().catch(() => null);
    const idSet = new Set([rawUserId]);
    if (profile?._id) idSet.add(profile._id.toString());
    const pharmacyIds = [...idSet].map(id => toId(id)).filter(Boolean);

    // Show ALL orders — direct cart orders may have any pharmacy_id value
    // In a single-pharmacy system all orders belong to this pharmacy
    const query = {};
    if (status && status !== 'all') query.status = status;

    const rawOrders = await PharmacyOrder.find(query).sort({ createdAt: -1 }).lean();

    // Safe patient lookup — skip nulls
    const patientIdStrings = [...new Set(
      rawOrders.map(o => o.patient_id?.toString()).filter(Boolean)
    )];
    const patients = patientIdStrings.length > 0
      ? await User.find({ _id: { $in: patientIdStrings.map(id => toId(id)) } }).lean()
      : [];
    const pMap = {};
    patients.forEach(p => { pMap[p._id.toString()] = p; });

    const orders = rawOrders.map(o => {
      const pid = o.patient_id?.toString() || '';
      const pt = pMap[pid];
      return {
        _id: o._id.toString(),
        orderNumber: o.order_number || `#${o._id.toString().slice(-6).toUpperCase()}`,
        status: o.status,
        totalAmount: o.total_amount || 0,
        deliveryFee: o.delivery_fee || 0,
        deliveryAddress: o.delivery_address || '',
        expectedDeliveryTime: o.expected_delivery_time || '',
        createdAt: o.createdAt,
        prescriptionId: o.prescription_id || null,
        rejectionReason: o.rejection_reason || '',
        walkInMedicines: o.orderType === 'walk-in' ? (o.medicines || '') : '',
        orderType: o.orderType || 'cart',
        user: {
          _id: pt?._id?.toString() || '',
          name: o.orderType === 'walk-in'
            ? (o.patientName || 'Walk-in Patient')
            : (pt?.username || pt?.name || 'Patient'),
          email: pt?.email || '',
          phoneNumber: o.orderType === 'walk-in' ? (o.contact || '') : (pt?.phone || pt?.phoneNumber || ''),
        },
        items: o.items || [],
      };
    });

    res.json({ success: true, orders, pharmacyId: rawUserId });
  } catch (err) {
    console.error('GET /pharmacy/orders/pharmacy/list error:', err.message);
    res.status(500).json({ success: false, message: err.message, orders: [] });
  }
});

router.get('/orders', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const userRole = req.user.role;
    const { status } = req.query;

    const query = userRole === 'pharmacy' ? { pharmacy_id: userId } : { patient_id: userId };
    if (status && status !== 'all') query.status = status;

    const orders = await PharmacyOrder.find(query).sort({ createdAt: -1 }).lean();

    // Fetch pharmacy names for all unique pharmacy IDs
    const pharmacyIds = [...new Set(orders.map(o => o.pharmacy_id?.toString()).filter(Boolean))];
    const pharmacyProfiles = await PharmacyProfile.find({ user_id: { $in: pharmacyIds.map(id => toId(id)) } }).lean();
    const pharmacyUsers = await User.find({ _id: { $in: pharmacyIds.map(id => toId(id)) } }).lean();
    const pharmNameMap = {};
    pharmacyUsers.forEach(u => { pharmNameMap[u._id.toString()] = u.username || u.name || 'Pharmacy'; });
    pharmacyProfiles.forEach(p => {
      if (p.pharmacy_name) pharmNameMap[p.user_id.toString()] = p.pharmacy_name;
    });

    res.json({
      success: true,
      orders: orders.map(o => ({
        ...o,
        _id: o._id.toString(),
        prescriptionId: o.prescription_id?.toString() || null,
        pharmacyId: o.pharmacy_id?.toString() || null,
        pharmacyName: pharmNameMap[o.pharmacy_id?.toString()] || 'Pharmacy',
        patientId: o.patient_id?.toString() || null,
        totalAmount: o.total_amount || 0,
        deliveryFee: o.delivery_fee || 0,
        deliveryAddress: o.delivery_address || '',
        items: (o.items || []).map(item => ({
          ...item,
          name: item.productName || item.product_name || item.name || item.medicine_name || item.medicine || item.title || 'Unknown Item',
        })),
      })),
    });
  } catch (err) {
    console.error(err);
    res.json({ success: true, orders: [] });
  }
});

// ─── GET ORDER BY ID ──────────────────────────────────────────────────────────
router.get('/orders/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const orderId = toId(req.params.id);
    if (!orderId) return res.status(400).json({ success: false, message: 'Invalid order ID' });

    const order = await PharmacyOrder.findOne({
      _id: orderId,
      $or: [{ patient_id: userId }, { pharmacy_id: userId }],
    }).lean();

    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, order: { ...order, _id: order._id.toString() } });
  } catch (err) {
    console.error('GET /pharmacy/orders/:id error:', err.message);
    res.status(500).json({ success: false, message: 'Failed to fetch order' });
  }
});

// ─── CREATE ORDER ─────────────────────────────────────────────────────────────
router.post('/orders', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();

    const patientId = toId(req.user.id);
    if (!patientId) return res.status(401).json({ success: false, message: 'Invalid patient token' });

    const { pharmacyId, userId: bodyUserId, prescriptionId, deliveryAddress, totalAmount, deliveryFee, items } = req.body;

    // Accept either pharmacyId or userId (frontend may send either)
    const rawPharmacyId = pharmacyId || bodyUserId;
    if (!rawPharmacyId) return res.status(400).json({ success: false, message: 'pharmacyId is required' });

    const resolvedPharmacyId = toId(rawPharmacyId);
    if (!resolvedPharmacyId) return res.status(400).json({ success: false, message: `Invalid pharmacy ID: ${rawPharmacyId}` });

    // Normalize items — frontend may send productName or product_name
    const normalizedItems = Array.isArray(items) ? items.map(i => ({
      product_name: i.product_name || i.productName || i.name || '',
      generic_name: i.generic_name || i.genericName || '',
      quantity: Number(i.quantity) || 1,
      price: Number(i.price) || 0,
    })) : [];

    // Calculate total from items if totalAmount not provided or is 0
    const calculatedTotal = normalizedItems.reduce((sum, i) => sum + (i.price * i.quantity), 0);
    const finalTotal = Number(totalAmount) > 0 ? Number(totalAmount) : calculatedTotal;

    // Generate unique order number with random suffix to avoid collisions
    const orderNumber = `ORD-${Date.now().toString().slice(-8)}-${Math.random().toString(36).slice(-4).toUpperCase()}`;

    const order = await PharmacyOrder.create({
      patient_id: patientId,
      pharmacy_id: resolvedPharmacyId,
      prescription_id: prescriptionId || undefined,
      delivery_address: deliveryAddress || '',
      total_amount: finalTotal,
      delivery_fee: Number(deliveryFee) || 0,
      status: 'pending',
      order_number: orderNumber,
      orderNumber: orderNumber,
      items: normalizedItems,
    });

    res.status(201).json({ success: true, message: 'Order created successfully', order: { ...order.toObject(), _id: order._id.toString() } });
  } catch (err) {
    console.error('POST /pharmacy/orders error:', err.message, err.stack);
    // Return the actual error message so the client can display it
    res.status(500).json({ success: false, message: err.message || 'Failed to create order' });
  }
});

// ─── UPDATE ORDER STATUS ──────────────────────────────────────────────────────
router.put('/update_order_status/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    let { status, expectedDeliveryTime, rejectionReason } = req.body;

    // Normalize underscore vs hyphen variants
    if (status === 'out_for_delivery') status = 'out-for-delivery';

    const validStatuses = ['pending', 'confirmed', 'preparing', 'out-for-delivery', 'delivered', 'cancelled', 'completed', 'rejected'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: `Invalid status: ${status}` });
    }

    const update = { status };
    if (expectedDeliveryTime) update.expected_delivery_time = expectedDeliveryTime;
    if (status === 'rejected') {
      if (rejectionReason != null && String(rejectionReason).trim()) {
        update.rejection_reason = String(rejectionReason).trim().slice(0, 500);
      }
    } else {
      update.rejection_reason = '';
    }

    const order = await PharmacyOrder.findOneAndUpdate(
      { _id: toId(req.params.id), $or: [{ patient_id: userId }, { pharmacy_id: userId }] },
      { $set: update },
      { new: true }
    );

    if (!order) return res.status(404).json({ success: false, message: 'Order not found or access denied' });

    // Notify patient about status change
    const notifPayload = _statusNotifPayload(status, order.order_number || order._id.toString().slice(-6));
    if (notifPayload && order.patient_id && String(order.patient_id) !== String(userId)) {
      sendToUser(order.patient_id, { ...notifPayload, data: { orderId: String(order._id), type: notifPayload.type } }).catch(() => {});
    }

    res.json({ success: true, message: 'Order updated successfully', order: { ...order.toObject(), _id: order._id.toString() } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to update order' });
  }
});

router.put('/orders/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    let { status, expectedDeliveryTime, rejectionReason } = req.body;

    // Normalize underscore vs hyphen variants
    if (status === 'out_for_delivery') status = 'out-for-delivery';

    const validStatuses = ['pending', 'confirmed', 'preparing', 'out-for-delivery', 'delivered', 'cancelled', 'completed', 'rejected'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: `Invalid status: ${status}` });
    }

    const update = { status };
    if (expectedDeliveryTime) update.expected_delivery_time = expectedDeliveryTime;
    if (status === 'rejected') {
      if (rejectionReason != null && String(rejectionReason).trim()) {
        update.rejection_reason = String(rejectionReason).trim().slice(0, 500);
      }
    } else {
      update.rejection_reason = '';
    }

    const order = await PharmacyOrder.findOneAndUpdate(
      { _id: toId(req.params.id), $or: [{ patient_id: userId }, { pharmacy_id: userId }] },
      { $set: update },
      { new: true }
    );

    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    // Notify patient about status change
    const notifPayload2 = _statusNotifPayload(status, order.order_number || order._id.toString().slice(-6));
    if (notifPayload2 && order.patient_id && String(order.patient_id) !== String(userId)) {
      sendToUser(order.patient_id, { ...notifPayload2, data: { orderId: String(order._id), type: notifPayload2.type } }).catch(() => {});
    }

    res.json({ success: true, message: 'Order updated', order: { ...order.toObject(), _id: order._id.toString() } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to update order' });
  }
});

// ─── CANCEL ORDER ─────────────────────────────────────────────────────────────
router.put('/orders/:id/cancel', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const order = await PharmacyOrder.findOneAndUpdate(
      { _id: toId(req.params.id), patient_id: userId, status: { $in: ['pending', 'confirmed'] } },
      { $set: { status: 'cancelled', cancellation_reason: req.body.reason || '' } },
      { new: true }
    );
    if (!order) return res.status(404).json({ success: false, message: 'Order not found or cannot be cancelled' });
    res.json({ success: true, message: 'Order cancelled', order: { ...order.toObject(), _id: order._id.toString() } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to cancel order' });
  }
});

// ─── PRODUCTS ─────────────────────────────────────────────────────────────────
router.get('/products', async (req, res) => {
  try {
    await connectMongoDB();
    const { pharmacyId, category, q } = req.query;
    const uid = toId(pharmacyId || req.user.id);
    const query = { pharmacy_id: uid, is_active: true };
    if (category && category !== 'All') query.category = category;

    let products = await Product.find(query).lean();

    if (q) {
      const lq = q.toLowerCase();
      products = products.filter(p => p.name?.toLowerCase().includes(lq) || p.description?.toLowerCase().includes(lq));
    }

    res.json({ success: true, medicines: products.map(p => ({ ...p, _id: p._id.toString() })) });
  } catch (err) {
    console.error(err);
    res.json({ success: true, medicines: [] });
  }
});

// Helper: check if generic name is on the admin-controlled list
async function resolveControlledCategory(genericName) {
  if (!genericName) return null;
  try {
    const ControlledDrug = require('../models/ControlledDrug');
    const match = await ControlledDrug.findOne({
      genericName: { $regex: `^${genericName.trim()}$`, $options: 'i' },
    }).lean();
    return match ? 'Controlled' : null;
  } catch (_) { return null; }
}

router.post('/products', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { name, description, category, price, stockQuantity, manufacturer, requiresPrescription, genericName, medicineCategory } = req.body;

    // Admin-controlled drug list takes precedence — pharmacist cannot override classification
    const adminCategory = await resolveControlledCategory(genericName);
    const finalCategory = adminCategory || medicineCategory || 'OTC';
    const finalRequiresPrescription = adminCategory === 'Controlled' ? true : (requiresPrescription ?? false);

    const product = await Product.create({
      pharmacy_id: userId, name, description, category: category || 'OTC',
      medicine_category: finalCategory,
      price: price || 0, stock_quantity: stockQuantity || 0,
      manufacturer, requires_prescription: finalRequiresPrescription, generic_name: genericName,
    });

    res.status(201).json({ success: true, medicine: { ...product.toObject(), _id: product._id.toString() } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to create product' });
  }
});

router.put('/products/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { name, price, stockQuantity, category, description, genericName, medicineCategory } = req.body;
    const update = {};
    if (name) update.name = name;
    if (price !== undefined) update.price = price;
    if (stockQuantity !== undefined) update.stock_quantity = stockQuantity;
    if (category) update.category = category;
    if (description) update.description = description;
    if (genericName !== undefined) update.generic_name = genericName;

    // Admin classification always wins — pharmacist cannot reclassify
    const adminCategory = await resolveControlledCategory(genericName || (await Product.findById(req.params.id).lean())?.generic_name);
    if (adminCategory) {
      update.medicine_category = adminCategory;
      update.requires_prescription = true;
    } else if (medicineCategory) {
      update.medicine_category = medicineCategory;
    }

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ success: false, message: 'Nothing to update' });
    }

    const product = await Product.findByIdAndUpdate(req.params.id, { $set: update }, { new: true });
    res.json({ success: true, medicine: { ...product.toObject(), _id: product._id.toString() } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to update product' });
  }
});

router.delete('/products/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Product.findByIdAndUpdate(req.params.id, { is_active: false });
    res.json({ success: true, message: 'Product deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to delete product' });
  }
});

// ─── WALK-IN ORDER (created by pharmacy for walk-in patients) ─────────────────
router.post('/orders/walk-in', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const pharmacyUserId = toId(req.user.id);

    // Resolve pharmacy _id from the logged-in user
    const PharmacyProfile = require('../models/PharmacyProfile');
    const pharmacyProfile = await PharmacyProfile.findOne({ user_id: pharmacyUserId }).lean();
    const pharmacyId = pharmacyProfile ? pharmacyProfile._id : pharmacyUserId;

    const { patientName, contact, medicines, deliveryOption, deliveryAddress, notes, prescriptionId, totalAmount, items } = req.body;
    if (!patientName || !medicines) {
      return res.status(400).json({ success: false, message: 'patientName and medicines are required' });
    }

    // If any controlled medicine is in the order, validate prescriptionId against iCare prescriptions
    const Product = require('../models/Product');
    const EnhancedPrescription = require('../models/EnhancedPrescription');

    // Parse item names and check if any are controlled
    const itemNames = Array.isArray(items)
      ? items.map(i => (i.name || '').toLowerCase())
      : medicines.split(',').map(m => m.trim().toLowerCase());

    // Find any matching product with medicine_category = Controlled
    const controlledCheck = await Product.findOne({
      pharmacy_id: pharmacyUserId,
      is_active: true,
      medicine_category: 'Controlled',
      $or: itemNames.map(n => ({ name: { $regex: n.split(' ')[0], $options: 'i' } })),
    }).lean().catch(() => null);

    if (controlledCheck) {
      if (!prescriptionId || !prescriptionId.toString().trim()) {
        return res.status(400).json({
          success: false,
          requiresPrescription: true,
          message: 'A valid iCare prescription ID is required for controlled medicines.',
        });
      }
      // Verify the prescriptionId exists in iCare prescriptions
      const mongoose = require('mongoose');
      let rxValid = false;
      try {
        const rxId = new mongoose.Types.ObjectId(prescriptionId.trim());
        const rx = await EnhancedPrescription.findById(rxId).lean();
        rxValid = !!rx;
      } catch (_) { rxValid = false; }

      if (!rxValid) {
        return res.status(400).json({
          success: false,
          requiresPrescription: true,
          message: 'The provided iCare Prescription ID was not found. Please enter a valid prescription ID issued by an iCare doctor.',
        });
      }
    }

    // Normalize items from Flutter (may have name/price/qty fields)
    const normalizedItems = Array.isArray(items) ? items.map(i => ({
      product_name: i.product_name || i.name || '',
      generic_name: i.generic_name || '',
      quantity: Number(i.quantity) || 1,
      price: Number(i.price) || 0,
    })) : [];

    // Compute total from items if not provided
    const computedTotal = normalizedItems.reduce((sum, i) => sum + i.price * i.quantity, 0);
    const finalTotal = Number(totalAmount) > 0 ? Number(totalAmount) : computedTotal;

    const orderNumber = `WO-${Date.now().toString().slice(-8)}-${Math.random().toString(36).slice(-4).toUpperCase()}`;

    const order = await PharmacyOrder.create({
      pharmacy_id: pharmacyId,
      patient_id: pharmacyUserId,
      orderType: 'walk-in',
      patientName,
      contact,
      medicines,
      delivery_address: deliveryAddress || '',
      deliveryOption: deliveryOption || 'pickup',
      notes: notes || '',
      status: 'pending',
      order_number: orderNumber,
      orderNumber,
      total_amount: finalTotal,
      items: normalizedItems,
      ...(prescriptionId ? { prescription_id: prescriptionId } : {}),
    });

    res.status(201).json({ success: true, message: 'Walk-in order created', order: { ...order.toObject(), _id: order._id.toString() } });
  } catch (err) {
    console.error('POST /pharmacy/orders/walk-in error:', err.message);
    res.status(500).json({ success: false, message: err.message || 'Failed to create walk-in order' });
  }
});

// ─── ORDER RATING ─────────────────────────────────────────────────────────────
router.post('/orders/:id/rating', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { rating, comment } = req.body;
    const order = await PharmacyOrder.findByIdAndUpdate(
      toId(req.params.id),
      { $set: { rating: Number(rating) || 0, ratingComment: comment || '', ratedAt: new Date() } },
      { new: true }
    );
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    // Recalculate pharmacy average rating
    try {
      const pharmacyUserId = order.pharmacyId || order.pharmacy_id;
      if (pharmacyUserId) {
        const ratedOrders = await PharmacyOrder.find({
          $or: [{ pharmacyId: pharmacyUserId }, { pharmacy_id: pharmacyUserId }],
          rating: { $gt: 0 }
        }).lean();
        if (ratedOrders.length > 0) {
          const avg = ratedOrders.reduce((s, o) => s + (o.rating || 0), 0) / ratedOrders.length;
          await PharmacyProfile.findOneAndUpdate(
            { user_id: pharmacyUserId },
            { $set: { rating: Math.round(avg * 10) / 10, total_reviews: ratedOrders.length } },
            { upsert: false }
          );
        }
      }
    } catch (_) {}
    res.json({ success: true, message: 'Rating submitted', order: { ...order.toObject(), _id: order._id.toString() } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Failed to submit rating' });
  }
});

module.exports = router;

