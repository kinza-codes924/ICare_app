const mongoose = require('mongoose');

const communityTopicSchema = new mongoose.Schema({
  name: { type: String, required: true, unique: true, trim: true },
}, { timestamps: true });

module.exports = mongoose.models.CommunityTopic || mongoose.model('CommunityTopic', communityTopicSchema);
