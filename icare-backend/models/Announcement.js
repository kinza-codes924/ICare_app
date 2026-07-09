const mongoose = require('mongoose');

// Google Classroom "Stream" equivalent — course announcements/posts
const announcementSchema = new mongoose.Schema({
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  authorId:     { type: mongoose.Schema.Types.ObjectId, ref: 'User',   required: true },
  authorName:   { type: String },
  authorRole:   { type: String, enum: ['instructor', 'student'], default: 'instructor' },
  content:      { type: String, required: true },
  attachmentUrl:{ type: String },
  attachmentName:{ type: String },
  comments: [{
    authorId:  { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    authorName:{ type: String },
    text:      { type: String },
    createdAt: { type: Date, default: Date.now },
  }],
}, { timestamps: true });

module.exports = mongoose.models.Announcement || mongoose.model('Announcement', announcementSchema);
