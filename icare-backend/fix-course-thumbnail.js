// One-time fix: set thumbnail for "Complete Health & Wellness Guide"
require('dotenv').config({ path: '.env.local' });
const mongoose = require('mongoose');

async function fixThumbnail() {
  await mongoose.connect(process.env.MONGO_URI);
  const Course = require('./models/Course');

  // Find the course first to see what fields it already has
  const course = await Course.findOne({ title: /Complete Health.*Wellness/i });

  if (!course) {
    console.log('❌ Course not found: "Complete Health & Wellness Guide"');
    await mongoose.disconnect();
    return;
  }

  console.log(`✅ Found course: "${course.title}" (${course._id})`);
  console.log(`   thumbnail:     ${course.thumbnail || '(empty)'}`);
  console.log(`   thumbnail_url: ${course.thumbnail_url || '(empty)'}`);

  // Use existing value if one field already has a URL, otherwise use stock image
  const existingUrl = course.thumbnail || course.thumbnail_url;
  const thumbnailUrl = existingUrl ||
    'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=800&q=80&auto=format&fit=crop';

  const updated = await Course.findByIdAndUpdate(
    course._id,
    { $set: { thumbnail: thumbnailUrl, thumbnail_url: thumbnailUrl } },
    { new: true }
  );

  console.log(`✅ Thumbnail set to: ${updated.thumbnail}`);
  await mongoose.disconnect();
}

fixThumbnail().catch(console.error);
