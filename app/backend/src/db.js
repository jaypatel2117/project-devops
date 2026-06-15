const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'retaildb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle DB client', err);
});

async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS products (
        id          SERIAL PRIMARY KEY,
        name        VARCHAR(255) NOT NULL,
        description TEXT,
        price       DECIMAL(10,2) NOT NULL,
        stock       INTEGER NOT NULL DEFAULT 0,
        category    VARCHAR(100),
        image_url   TEXT,
        created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS orders (
        id             SERIAL PRIMARY KEY,
        customer_name  VARCHAR(255) NOT NULL,
        customer_email VARCHAR(255) NOT NULL,
        total_amount   DECIMAL(10,2) NOT NULL,
        status         VARCHAR(50) DEFAULT 'pending',
        created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS order_items (
        id         SERIAL PRIMARY KEY,
        order_id   INTEGER REFERENCES orders(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id),
        quantity   INTEGER NOT NULL,
        price      DECIMAL(10,2) NOT NULL
      );
    `);

    const { rows } = await client.query('SELECT COUNT(*) FROM products');
    if (parseInt(rows[0].count) === 0) {
      await client.query(`
        INSERT INTO products (name, description, price, stock, category, image_url) VALUES
        ('Wireless Headphones',  'Premium noise-cancelling headphones with 30hr battery', 129.99, 50,  'Electronics',   'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400'),
        ('Running Shoes',        'Lightweight mesh trainers for road and trail',           89.99,  100, 'Footwear',      'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400'),
        ('Coffee Maker',         '12-cup programmable drip coffee maker',                  59.99,  75,  'Kitchen',       'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400'),
        ('Yoga Mat',             'Non-slip 6mm thick mat with carrying strap',             39.99,  120, 'Sports',        'https://images.unsplash.com/photo-1601925228058-ccb2e22a84b3?w=400'),
        ('Smart Watch',          'Health tracking, GPS, and notifications on your wrist',  199.99, 30,  'Electronics',   'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400'),
        ('Backpack 30L',         'Water-resistant daypack with laptop sleeve',              49.99,  80,  'Accessories',   'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400'),
        ('Standing Desk',        'Electric height-adjustable desk 120cm',                  349.99, 20,  'Furniture',     'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=400'),
        ('Mechanical Keyboard',  'Compact TKL keyboard with Cherry MX Blue switches',      109.99, 45,  'Electronics',   'https://images.unsplash.com/photo-1541140532154-b024d705b90a?w=400')
      `);
    }

    console.log('Database initialised successfully');
  } finally {
    client.release();
  }
}

module.exports = { pool, initDB };
