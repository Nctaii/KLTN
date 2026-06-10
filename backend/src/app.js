// Cấu hình Express app: middleware, routes, xử lý lỗi
const express = require('express');
const cors = require('cors');

const authRoutes = require('./modules/auth/auth.routes');
const scenarioRoutes = require('./modules/scenario/scenario.routes');
const playRoutes = require('./modules/play/play.routes');
const errorMiddleware = require('./middleware/error.middleware');

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Kiểm tra sức khỏe server
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Gắn các nhóm route
app.use('/auth', authRoutes);
app.use('/scenarios', scenarioRoutes);
app.use('/play', playRoutes);

// Route không tồn tại
app.use((req, res) => {
  res.status(404).json({ error: 'Không tìm thấy endpoint' });
});

// Middleware xử lý lỗi (phải đặt cuối cùng)
app.use(errorMiddleware);

module.exports = app;
