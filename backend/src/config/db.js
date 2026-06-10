// Kết nối PostgreSQL dùng connection pool (pg)
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

pool.on('error', (err) => {
  console.error('Lỗi pool PostgreSQL:', err);
});

// Hàm query dùng chung cho toàn app
async function query(text, params) {
  return pool.query(text, params);
}

// Hàm chạy nhiều lệnh trong một transaction
async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, withTransaction };
