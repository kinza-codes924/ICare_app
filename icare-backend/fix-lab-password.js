// One-time script: reset testlaboratory@gmail.com password to '12345678'
require('dotenv').config({ path: '.env.local' });
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

async function fixPassword() {
  await mongoose.connect(process.env.MONGO_URI);
  const User = require('./models/User');

  const hashed = await bcrypt.hash('12345678', 10);
  const result = await User.findOneAndUpdate(
    { email: 'testlaboratory@gmail.com' },
    { $set: { password: hashed, is_approved: true, is_active: true } },
    { new: true }
  );

  if (!result) {
    console.log('❌ User not found: testlaboratory@gmail.com');
  } else {
    console.log(`✅ Password reset + approved for ${result.email} (role: ${result.role})`);
  }

  await mongoose.disconnect();
}

fixPassword().catch(console.error);
