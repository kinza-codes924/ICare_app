const mongoose = require('mongoose');

const courseCategorySchema = new mongoose.Schema({
  name:        { type: String, required: true, unique: true, trim: true },
  value:       { type: String, required: true, unique: true, trim: true }, // slug used in Course.category
  description: { type: String, default: '' },
  isActive:    { type: Boolean, default: true },
  order:       { type: Number, default: 0 },
}, { timestamps: true });

module.exports = mongoose.models.CourseCategory || mongoose.model('CourseCategory', courseCategorySchema);
