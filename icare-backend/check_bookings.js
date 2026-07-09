require('dotenv').config({ path: '.env.production' });
const mongoose = require('mongoose');

const uri = (process.env.MONGO_URI || '').replace(/\\n/g, '').trim();
console.log('Connecting to MongoDB...');

mongoose.connect(uri).then(async () => {
  console.log('Connected!');

  const LabTestRequest = require('./models/LabTestRequest');
  const User = require('./models/User');

  const count = await LabTestRequest.countDocuments();
  console.log('\n=== Total Lab Bookings in DB:', count, '===\n');

  const recent = await LabTestRequest.find().sort({ createdAt: -1 }).limit(10).lean();

  for (const b of recent) {
    const patient = await User.findById(b.patient_id).lean();
    const lab = await User.findById(b.lab_id).lean();
    console.log({
      _id: b._id.toString(),
      lab_id: b.lab_id?.toString(),
      lab_name: lab?.username || lab?.name || 'Unknown',
      patient_id: b.patient_id?.toString(),
      patient_name: patient?.username || patient?.name || 'Unknown',
      test_type: b.test_type,
      status: b.status,
      collection_type: b.collection_type,
      createdAt: b.createdAt,
    });
  }

  // Also check lab users
  console.log('\n=== Lab Users in DB ===');
  const labs = await User.find({ role: { $in: ['lab', 'Lab', 'laboratory', 'Laboratory'] } }).lean();
  labs.forEach(l => console.log({ _id: l._id.toString(), name: l.username || l.name, role: l.role }));

  process.exit(0);
}).catch(e => {
  console.error('DB Error:', e.message);
  process.exit(1);
});
