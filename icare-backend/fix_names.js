const mongoose = require('mongoose');
const uri = 'mongodb+srv://icaredev02_db_user:icaredev02@cluster0.kalraci.mongodb.net/icare_production';
const updates = [
  { email: 'muhammadali.dentist@icaretest.com', name: 'Muhammad Ali' },
  { email: 'ahmedkhan.derma@icaretest.com', name: 'Ahmed Khan' },
  { email: 'hamzashah.gyne@icaretest.com', name: 'Hamza Shah' },
  { email: 'usmanmalik.physio@icaretest.com', name: 'Usman Malik' },
  { email: 'bilalahmed.psych@icaretest.com', name: 'Bilal Ahmed' },
  { email: 'hassanraza.nutri2@icaretest.com', name: 'Hassan Raza' },
];
mongoose.connect(uri).then(async () => {
  const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }), 'users');
  for (const u of updates) {
    const r = await User.updateOne({ email: u.email }, { $set: { name: u.name, username: u.name } });
    console.log(u.email, '->', u.name, '| matched:', r.matchedCount, 'modified:', r.modifiedCount);
  }
  await mongoose.disconnect();
  console.log('Done');
}).catch(e => console.error(e.message));
