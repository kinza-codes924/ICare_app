const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const Product = require('../models/Product');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── DOWNLOAD CSV TEMPLATE ────────────────────────────────────────────────────
router.get('/template', authMiddleware, (req, res) => {
  if (req.user.role !== 'pharmacy') {
    return res.status(403).json({ success: false, message: 'Only pharmacies can download inventory template' });
  }

  const csvContent = `name,generic_name,description,category,medicine_category,price,stock_quantity,manufacturer,requires_prescription
Paracetamol 500mg,Acetaminophen,Pain reliever and fever reducer,Pain Relief,OTC,50.00,100,ABC Pharma,false
Alprazolam 0.5mg,Alprazolam,Anti-anxiety medication,Mental Health,Controlled,150.00,50,XYZ Pharma,true
COVID-19 Vaccine,mRNA-1273,Moderna COVID-19 vaccine,Vaccines,Vaccine,0.00,20,Moderna,true`;

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=icare-inventory-template.csv');
  res.send(csvContent);
});

// ─── EXPORT INVENTORY AS CSV ──────────────────────────────────────────────────
router.get('/export', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role !== 'pharmacy') {
      return res.status(403).json({ success: false, message: 'Only pharmacies can export inventory' });
    }

    const pharmacyId = toId(req.user.id);
    const products = await Product.find({ pharmacy_id: pharmacyId, is_active: true }).sort({ name: 1 }).lean();

    if (products.length === 0) {
      return res.status(404).json({ success: false, message: 'No products found to export' });
    }

    const headers = 'name,generic_name,description,category,medicine_category,price,stock_quantity,manufacturer,requires_prescription\n';
    const rows = products.map(p => [
      escapeCsvField(p.name),
      escapeCsvField(p.generic_name || ''),
      escapeCsvField(p.description || ''),
      escapeCsvField(p.category || ''),
      escapeCsvField(p.medicine_category || 'OTC'),
      p.price,
      p.stock_quantity,
      escapeCsvField(p.manufacturer || ''),
      p.requires_prescription || false,
    ].join(',')).join('\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=icare-inventory-export.csv');
    res.send(headers + rows);
  } catch (error) {
    console.error('Export inventory error:', error);
    res.status(500).json({ success: false, message: 'Failed to export inventory' });
  }
});

// ─── IMPORT INVENTORY FROM CSV ────────────────────────────────────────────────
router.post('/import', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if (req.user.role !== 'pharmacy') {
      return res.status(403).json({ success: false, message: 'Only pharmacies can import inventory' });
    }

    const pharmacyId = toId(req.user.id);
    const { csvData } = req.body;

    if (!csvData || typeof csvData !== 'string') {
      return res.status(400).json({ success: false, message: 'CSV data is required' });
    }

    const lines = csvData.trim().split('\n');
    if (lines.length < 2) {
      return res.status(400).json({ success: false, message: 'CSV file is empty or invalid' });
    }

    const headers = lines[0].split(',').map(h => h.trim());
    const expectedHeaders = ['name', 'generic_name', 'description', 'category', 'medicine_category', 'price', 'stock_quantity', 'manufacturer', 'requires_prescription'];
    const hasAllHeaders = expectedHeaders.every(h => headers.includes(h));
    if (!hasAllHeaders) {
      return res.status(400).json({ success: false, message: 'Invalid CSV format. Please use the provided template.' });
    }

    const products = [];
    const errors = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;

      const values = parseCsvLine(line);
      if (values.length !== headers.length) {
        errors.push(`Row ${i + 1}: Invalid number of columns`);
        continue;
      }

      const product = {};
      headers.forEach((header, index) => { product[header] = values[index]; });

      if (!product.name || !product.price) {
        errors.push(`Row ${i + 1}: Name and price are required`);
        continue;
      }

      const validCategories = ['OTC', 'Controlled', 'Vaccine'];
      if (product.medicine_category && !validCategories.includes(product.medicine_category)) {
        errors.push(`Row ${i + 1}: Invalid medicine_category. Must be OTC, Controlled, or Vaccine`);
        continue;
      }

      products.push({
        pharmacy_id: pharmacyId,
        name: product.name,
        generic_name: product.generic_name || null,
        description: product.description || '',
        category: product.category || 'general',
        medicine_category: product.medicine_category || 'OTC',
        price: parseFloat(product.price) || 0,
        stock_quantity: parseInt(product.stock_quantity) || 0,
        manufacturer: product.manufacturer || '',
        requires_prescription: product.requires_prescription === 'true' || product.requires_prescription === '1',
        is_active: true,
      });
    }

    if (products.length === 0) {
      return res.status(400).json({ success: false, message: 'No valid products found in CSV', errors });
    }

    let successCount = 0;
    for (const product of products) {
      try {
        await Product.create(product);
        successCount++;
      } catch (err) {
        errors.push(`Failed to import "${product.name}": ${err.message}`);
      }
    }

    res.status(200).json({
      success: true,
      message: `Successfully imported ${successCount} products`,
      imported: successCount,
      total: products.length,
      errors: errors.length > 0 ? errors : undefined,
    });
  } catch (error) {
    console.error('Import inventory error:', error);
    res.status(500).json({ success: false, message: 'Failed to import inventory' });
  }
});

function escapeCsvField(field) {
  if (!field) return '';
  const str = String(field);
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function parseCsvLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];
    if (char === '"') {
      if (inQuotes && nextChar === '"') { current += '"'; i++; }
      else { inQuotes = !inQuotes; }
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

module.exports = router;
