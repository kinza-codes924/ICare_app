const { v2: cloudinary } = require('cloudinary');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'dzlcnyxgb',
  api_key: process.env.CLOUDINARY_API_KEY || '951538238996719',
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

module.exports = cloudinary;
