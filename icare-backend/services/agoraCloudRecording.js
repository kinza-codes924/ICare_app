/**
 * Agora Cloud Recording service
 * Docs: https://docs.agora.io/en/cloud-recording/reference/rest-api/
 *
 * Required env vars:
 *   AGORA_APP_ID            — already set
 *   AGORA_APP_CERTIFICATE   — already set
 *   AGORA_CUSTOMER_KEY      — from Agora Console → RESTful API
 *   AGORA_CUSTOMER_SECRET   — from Agora Console → RESTful API
 *   AGORA_S3_BUCKET         — AWS S3 bucket name
 *   AGORA_S3_ACCESS_KEY     — AWS IAM access key
 *   AGORA_S3_SECRET_KEY     — AWS IAM secret key
 *   AGORA_S3_REGION         — 0=us-east-1 (default), 1=us-east-2, 2=us-west-1, 3=us-west-2, 4=eu-west-1
 */

const { RtcTokenBuilder, RtcRole } = require('agora-token');

const APP_ID = (process.env.AGORA_APP_ID || '').trim();
const APP_CERTIFICATE = (process.env.AGORA_APP_CERTIFICATE || '').trim();
const CUSTOMER_KEY = (process.env.AGORA_CUSTOMER_KEY || '').trim();
const CUSTOMER_SECRET = (process.env.AGORA_CUSTOMER_SECRET || '').trim();

const S3_BUCKET = (process.env.AGORA_S3_BUCKET || '').trim();
const S3_ACCESS_KEY = (process.env.AGORA_S3_ACCESS_KEY || '').trim();
const S3_SECRET_KEY = (process.env.AGORA_S3_SECRET_KEY || '').trim();
const S3_REGION = parseInt(process.env.AGORA_S3_REGION || '0', 10);

// Fixed UID used by the recording bot (must not conflict with real users)
const RECORDER_UID = 987654321;

const BASE_URL = `https://api.agora.io/v1/apps/${APP_ID}/cloud_recording`;

function isConfigured() {
  return !!(APP_ID && APP_CERTIFICATE && CUSTOMER_KEY && CUSTOMER_SECRET &&
            S3_BUCKET && S3_ACCESS_KEY && S3_SECRET_KEY);
}

function authHeader() {
  const creds = Buffer.from(`${CUSTOMER_KEY}:${CUSTOMER_SECRET}`).toString('base64');
  return `Basic ${creds}`;
}

function generateRecorderToken(channelName) {
  const expire = Math.floor(Date.now() / 1000) + 7200;
  return RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channelName, RECORDER_UID,
    RtcRole.SUBSCRIBER, expire, expire
  );
}

async function agoraPost(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': authHeader(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Agora API error ${res.status}: ${JSON.stringify(data)}`);
  return data;
}

/**
 * Step 1 — Acquire a cloud recording resource ID
 */
async function acquireResource(channelName) {
  const data = await agoraPost(`${BASE_URL}/acquire`, {
    cname: channelName,
    uid: String(RECORDER_UID),
    clientRequest: {
      scene: 0,
      resourceExpiredHour: 24,
    },
  });
  return data.resourceId;
}

/**
 * Step 2 — Start composite recording (all streams mixed into one MP4)
 */
async function startRecording(channelName, resourceId) {
  const token = generateRecorderToken(channelName);
  const data = await agoraPost(
    `${BASE_URL}/resourceid/${resourceId}/mode/mix/start`,
    {
      cname: channelName,
      uid: String(RECORDER_UID),
      clientRequest: {
        token,
        storageConfig: {
          vendor: 1,           // AWS S3
          region: S3_REGION,
          bucket: S3_BUCKET,
          accessKey: S3_ACCESS_KEY,
          secretKey: S3_SECRET_KEY,
          fileNamePrefix: ['lms-recordings'],
        },
        recordingConfig: {
          maxIdleTime: 60,
          streamTypes: 3,      // 0=audio, 1=video, 3=both
          channelType: 0,      // 0=communication, 1=live-broadcast
          videoStreamType: 0,  // 0=high stream
          transcodingConfig: {
            width: 1280,
            height: 720,
            fps: 24,
            bitrate: 2260,
            mixedVideoLayout: 1,  // floating layout
            backgroundColor: '#1C2333',
          },
        },
        recordingFileConfig: {
          avFileType: ['hls', 'mp4'],
        },
      },
    }
  );
  return data.sid;
}

/**
 * Step 3 — Stop recording and get the file list
 * Returns: { sid, resourceId, mp4Url, fileList }
 */
async function stopRecording(channelName, resourceId, sid) {
  const data = await agoraPost(
    `${BASE_URL}/resourceid/${resourceId}/sid/${sid}/mode/mix/stop`,
    {
      cname: channelName,
      uid: String(RECORDER_UID),
      clientRequest: {},
    }
  );

  const serverResponse = data.serverResponse || {};
  const fileList = serverResponse.fileList || [];

  // Find the MP4 file (prefer it over HLS)
  const mp4 = fileList.find(f => f.fileName?.endsWith('.mp4'));
  const firstFile = fileList[0];
  const chosenFile = mp4 || firstFile;

  const mp4Url = chosenFile
    ? `https://${S3_BUCKET}.s3.amazonaws.com/${chosenFile.fileName}`
    : '';

  return {
    sid: data.sid,
    resourceId: data.resourceId,
    mp4Url,
    fileList,
  };
}

module.exports = {
  isConfigured,
  acquireResource,
  startRecording,
  stopRecording,
  RECORDER_UID,
};
