const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: String,
  content: { type: String, required: true },
}, { timestamps: true });

const communityPostSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: String,
  userRole: String,
  content: { type: String, required: true },
  imageUrl: String,
  category: { type: String, default: 'General' },
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  comments: [commentSchema],
  resharedFrom: { type: mongoose.Schema.Types.ObjectId, ref: 'CommunityPost', default: null },
  resharedFromUser: { type: String, default: null },
}, { timestamps: true });

module.exports = mongoose.model('CommunityPost', communityPostSchema);
