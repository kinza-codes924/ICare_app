/**
 * One-time script: adds 3 controlled medicines to the first pharmacy in MongoDB.
 * Run with: node seed_controlled_medicines.js
 */
const mongoose = require('mongoose');
require('dotenv').config({ path: '.env.production' });

const User = require('./models/User');
const Product = require('./models/Product');

async function seed() {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.DATABASE_URL;
  if (!uri) { console.error('No MONGODB_URI in .env'); process.exit(1); }

  await mongoose.connect(uri);
  console.log('Connected to MongoDB');

  // Find first pharmacy user
  const pharmacy = await User.findOne({ role: { $in: ['pharmacy', 'Pharmacy'] } }).lean();
  if (!pharmacy) { console.error('No pharmacy user found'); process.exit(1); }
  console.log(`Using pharmacy: ${pharmacy.username || pharmacy.email} (${pharmacy._id})`);

  const medicines = [
    {
      pharmacy_id: pharmacy._id,
      name: 'Xanax (Alprazolam) 0.5mg',
      generic_name: 'Alprazolam',
      description: 'Controlled benzodiazepine for anxiety disorders. Schedule IV controlled substance.',
      category: 'psychiatric',
      medicine_category: 'Controlled',
      price: 450,
      stock_quantity: 50,
      manufacturer: 'Pfizer',
      requires_prescription: true,
      is_active: true,
    },
    {
      pharmacy_id: pharmacy._id,
      name: 'Tramadol HCl 50mg',
      generic_name: 'Tramadol Hydrochloride',
      description: 'Controlled opioid analgesic for moderate to severe pain. Schedule IV.',
      category: 'analgesics',
      medicine_category: 'Controlled',
      price: 320,
      stock_quantity: 30,
      manufacturer: 'Searle Pakistan',
      requires_prescription: true,
      is_active: true,
    },
    {
      pharmacy_id: pharmacy._id,
      name: 'Codeine Phosphate 30mg',
      generic_name: 'Codeine',
      description: 'Controlled opioid for pain relief and cough suppression. Schedule II.',
      category: 'analgesics',
      medicine_category: 'Controlled',
      price: 280,
      stock_quantity: 20,
      manufacturer: 'Martin Dow',
      requires_prescription: true,
      is_active: true,
    },
  ];

  for (const med of medicines) {
    const existing = await Product.findOne({ name: med.name, pharmacy_id: pharmacy._id });
    if (existing) {
      console.log(`  SKIP (already exists): ${med.name}`);
      continue;
    }
    await Product.create(med);
    console.log(`  ADDED: ${med.name}`);
  }

  console.log('\nDone. Controlled medicines added.');
  await mongoose.disconnect();
}

seed().catch(err => { console.error(err); process.exit(1); });
