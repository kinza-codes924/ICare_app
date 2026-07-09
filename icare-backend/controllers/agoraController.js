const { RtcTokenBuilder, RtcRole } = require('agora-token');

const APP_ID = (process.env.AGORA_APP_ID || '').trim();
const APP_CERTIFICATE = (process.env.AGORA_APP_CERTIFICATE || '').trim();

const TOKEN_EXPIRE_SECONDS = 3600; // 1 hour

// GET /api/agora/token?channelName=xxx&uid=0
const getToken = (req, res) => {
  try {
    const { channelName, uid = 0 } = req.query;

    if (!channelName) {
      return res.status(400).json({ success: false, message: 'channelName is required' });
    }

    if (!APP_ID || !APP_CERTIFICATE) {
      return res.status(500).json({ success: false, message: 'Agora credentials not configured on server' });
    }

    const uidNum = parseInt(uid, 10) || 0;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const tokenExpire = currentTimestamp + TOKEN_EXPIRE_SECONDS;
    const privilegeExpire = currentTimestamp + TOKEN_EXPIRE_SECONDS;

    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      uidNum,
      RtcRole.PUBLISHER,
      tokenExpire,
      privilegeExpire,
    );

    return res.json({
      success: true,
      data: {
        token,
        appId: APP_ID,
        channelName,
        uid: uidNum,
        expiresAt: tokenExpire,
      },
    });
  } catch (err) {
    console.error('Agora token error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = { getToken };
