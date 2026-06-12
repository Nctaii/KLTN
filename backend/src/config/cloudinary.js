// Cấu hình Cloudinary + hàm upload ảnh từ buffer (bộ nhớ) lên Cloudinary
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/**
 * Upload một ảnh (dạng buffer) lên Cloudinary.
 * @param {Buffer} buffer - dữ liệu ảnh trong bộ nhớ (từ multer memoryStorage)
 * @param {string} folder - thư mục trên Cloudinary (vd 'covers', 'avatars')
 * @returns {Promise<string>} URL đầy đủ (https) của ảnh đã upload
 */
function uploadToCloudinary(buffer, folder) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: `interactive_novel/${folder}`,
        resource_type: 'image',
        // Tối ưu: tự chọn định dạng & chất lượng tốt nhất
        transformation: [{ quality: 'auto', fetch_format: 'auto' }],
      },
      (error, result) => {
        if (error) return reject(error);
        resolve(result.secure_url); // URL https đầy đủ
      }
    );
    stream.end(buffer);
  });
}

module.exports = { cloudinary, uploadToCloudinary };