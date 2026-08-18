const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { sendEmail } = require('../utils/email');

// POST /api/support — "Report an Issue" from help_and_support.dart, submitted
// in-app instead of opening the user's email client via a mailto: link.
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { category, subject, message, name, email, role, userId } = req.body;
    if (!subject || !message) {
      return res.status(400).json({ success: false, message: 'Subject and message are required' });
    }

    const html = `
      <p><b>Category:</b> ${category || 'General'}</p>
      <p><b>Subject:</b> ${subject}</p>
      <p><b>Name:</b> ${name || 'N/A'}</p>
      <p><b>Email:</b> ${email || 'N/A'}</p>
      <p><b>Account Type:</b> ${role || 'N/A'}</p>
      <p><b>User ID:</b> ${userId || req.user.id || 'N/A'}</p>
      <p><b>Message:</b><br/>${String(message).replace(/\n/g, '<br/>')}</p>
    `;

    await sendEmail({
      to: 'HR@icare.com.co',
      subject: `[iCare Support] [${category || 'General'}] ${subject}`,
      html,
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
