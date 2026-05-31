// One-time script: fix testLaboratory@gmail.com role from 'instructor' to 'lab'
require('dotenv').config({ path: '.env.local' });
const mongoose = require('mongoose');

async function fixRole() {
  await mongoose.connect(process.env.MONGO_URI);
  const User = require('./models/User');

  const result = await User.findOneAndUpdate(
    { email: 'testLaboratory@gmail.com' },
    { $set: { role: 'lab' } },
    { new: true }
  );

  if (!result) {
    console.log('❌ User not found: testLaboratory@gmail.com');
  } else {
    console.log(`✅ Role updated → ${result.role} for ${result.email}`);
  }

  await mongoose.disconnect();
}

fixRole().catch(console.error);
