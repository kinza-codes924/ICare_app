const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const CommunityPost = require('../models/CommunityPost');
const CommunityTopic = require('../models/CommunityTopic');
const { authMiddleware } = require('../middleware/auth');
const cloudinary = require('../config/cloudinary');

const DEFAULT_CATEGORIES = [
  'General', 'Diabetes', 'Heart Health', 'Mental Wellness',
  'Nutrition', 'Pregnancy', 'COVID-19',
];

function isAdmin(user) {
  return user?.role?.toLowerCase() === 'admin';
}

// GET /api/community/categories
router.get('/categories', async (req, res) => {
  try {
    await connectMongoDB();
    const custom = await CommunityTopic.find().sort({ createdAt: 1 }).lean();
    const customNames = custom.map(t => t.name);
    const all = [...new Set([...DEFAULT_CATEGORIES, ...customNames])];
    res.json({ success: true, categories: all });
  } catch (err) {
    res.json({ success: true, categories: DEFAULT_CATEGORIES });
  }
});

// POST /api/community/categories — admin only
router.post('/categories', authMiddleware, async (req, res) => {
  try {
    if (!isAdmin(req.user)) {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }
    await connectMongoDB();
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Topic name required' });
    }
    const topic = await CommunityTopic.findOneAndUpdate(
      { name: name.trim() },
      { name: name.trim() },
      { upsert: true, new: true }
    );
    res.json({ success: true, topic });
  } catch (err) {
    console.error('POST /community/categories error:', err);
    res.status(500).json({ success: false, message: 'Failed to add topic' });
  }
});

// GET /api/community/posts — fetch posts (public)
router.get('/posts', async (req, res) => {
  try {
    await connectMongoDB();
    const { category, limit = 50, skip = 0 } = req.query;
    const filter = {};
    if (category && category !== 'All') filter.category = category;

    const posts = await CommunityPost.find(filter)
      .sort({ createdAt: -1 })
      .limit(Number(limit))
      .skip(Number(skip))
      .lean();

    const formatted = posts.map(p => ({
      ...p,
      id: p._id.toString(),
      likeCount: (p.likes || []).length,
      commentCount: (p.comments || []).length,
    }));

    res.json({ success: true, posts: formatted });
  } catch (err) {
    console.error('GET /community/posts error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch posts' });
  }
});

// POST /api/community/posts — create a post (auth required)
router.post('/posts', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { content, category, image, imageUrl } = req.body;

    if (!content || content.trim() === '') {
      return res.status(400).json({ success: false, message: 'Content is required' });
    }

    let finalImageUrl = imageUrl || null;

    if (image && image.startsWith('data:')) {
      try {
        const uploadResult = await cloudinary.uploader.upload(image, {
          folder: 'community_posts',
          resource_type: 'image',
          transformation: [{ width: 1200, height: 1200, crop: 'limit', quality: 'auto' }],
        });
        finalImageUrl = uploadResult.secure_url;
      } catch (uploadErr) {
        console.error('Cloudinary upload error:', uploadErr);
      }
    }

    const post = await CommunityPost.create({
      userId: req.user.id,
      userName: req.user.name || req.user.username,
      userRole: req.user.role,
      content: content.trim(),
      category: category || 'General',
      imageUrl: finalImageUrl,
    });

    res.status(201).json({
      success: true,
      post: { ...post.toObject(), id: post._id.toString(), likeCount: 0, commentCount: 0 },
    });
  } catch (err) {
    console.error('POST /community/posts error:', err);
    res.status(500).json({ success: false, message: 'Failed to create post' });
  }
});

// POST /api/community/posts/:id/like — toggle like
router.post('/posts/:id/like', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const post = await CommunityPost.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    const userId = req.user.id;
    const alreadyLiked = post.likes.some(l => l.toString() === userId.toString());
    if (alreadyLiked) {
      post.likes = post.likes.filter(l => l.toString() !== userId.toString());
    } else {
      post.likes.push(userId);
    }
    await post.save();

    res.json({ success: true, liked: !alreadyLiked, likeCount: post.likes.length });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to like post' });
  }
});

// POST /api/community/posts/:id/comment — add comment
router.post('/posts/:id/comment', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { content } = req.body;
    if (!content || content.trim() === '') {
      return res.status(400).json({ success: false, message: 'Comment cannot be empty' });
    }

    const post = await CommunityPost.findByIdAndUpdate(
      req.params.id,
      {
        $push: {
          comments: {
            userId: req.user.id,
            userName: req.user.name || req.user.username,
            content: content.trim(),
          },
        },
      },
      { new: true }
    );
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    const newComment = post.comments[post.comments.length - 1];
    res.json({ success: true, comment: newComment, commentCount: post.comments.length });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to add comment' });
  }
});

// POST /api/community/posts/:id/reshare — reshare a post
router.post('/posts/:id/reshare', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const original = await CommunityPost.findById(req.params.id);
    if (!original) return res.status(404).json({ success: false, message: 'Post not found' });

    const reshared = await CommunityPost.create({
      userId: req.user.id,
      userName: req.user.name || req.user.username,
      userRole: req.user.role,
      content: original.content,
      category: original.category,
      imageUrl: original.imageUrl,
      resharedFrom: original._id,
      resharedFromUser: original.userName,
    });

    res.status(201).json({
      success: true,
      message: 'Post reshared successfully',
      post: { ...reshared.toObject(), id: reshared._id.toString(), likeCount: 0, commentCount: 0 },
    });
  } catch (err) {
    console.error('POST /community/posts/:id/reshare error:', err);
    res.status(500).json({ success: false, message: 'Failed to reshare post' });
  }
});

// DELETE /api/community/posts/:id — owner or admin can delete
router.delete('/posts/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const post = await CommunityPost.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    if (!isAdmin(req.user) && post.userId.toString() !== req.user.id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    await post.deleteOne();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to delete post' });
  }
});

// DELETE /api/community/posts/:id/comments/:commentId — admin or comment owner
router.delete('/posts/:id/comments/:commentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const post = await CommunityPost.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    const comment = post.comments.id(req.params.commentId);
    if (!comment) return res.status(404).json({ success: false, message: 'Comment not found' });

    if (!isAdmin(req.user) && comment.userId.toString() !== req.user.id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    post.comments.pull(req.params.commentId);
    await post.save();
    res.json({ success: true, commentCount: post.comments.length });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to delete comment' });
  }
});

module.exports = router;
