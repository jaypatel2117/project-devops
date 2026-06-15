const { Router } = require('express');
const { body, param, validationResult } = require('express-validator');
const { pool } = require('../db');

const router = Router();

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
};

router.get('/', async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        o.id, o.customer_name, o.customer_email, o.total_amount, o.status, o.created_at,
        COALESCE(
          json_agg(
            json_build_object(
              'product_id', oi.product_id,
              'name',       p.name,
              'quantity',   oi.quantity,
              'price',      oi.price
            )
          ) FILTER (WHERE oi.id IS NOT NULL),
          '[]'
        ) AS items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products    p  ON oi.product_id = p.id
      GROUP BY o.id
      ORDER BY o.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id', param('id').isInt({ min: 1 }), validate, async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        o.id, o.customer_name, o.customer_email, o.total_amount, o.status, o.created_at,
        COALESCE(
          json_agg(
            json_build_object(
              'product_id', oi.product_id,
              'name',       p.name,
              'quantity',   oi.quantity,
              'price',      oi.price
            )
          ) FILTER (WHERE oi.id IS NOT NULL),
          '[]'
        ) AS items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products    p  ON oi.product_id = p.id
      WHERE o.id = $1
      GROUP BY o.id
    `, [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Order not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post(
  '/',
  [
    body('customer_name').trim().notEmpty(),
    body('customer_email').isEmail().normalizeEmail(),
    body('items').isArray({ min: 1 }),
    body('items.*.product_id').isInt({ min: 1 }),
    body('items.*.quantity').isInt({ min: 1 }),
  ],
  validate,
  async (req, res) => {
    const { customer_name, customer_email, items } = req.body;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Verify products exist and have enough stock
      for (const item of items) {
        const { rows } = await client.query(
          'SELECT id, price, stock FROM products WHERE id = $1 FOR UPDATE',
          [item.product_id]
        );
        if (!rows.length) throw new Error(`Product ${item.product_id} not found`);
        if (rows[0].stock < item.quantity)
          throw new Error(`Insufficient stock for product ${item.product_id}`);
        item.price = parseFloat(rows[0].price);
      }

      const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

      const { rows: orderRows } = await client.query(
        'INSERT INTO orders (customer_name, customer_email, total_amount) VALUES ($1,$2,$3) RETURNING *',
        [customer_name, customer_email, total.toFixed(2)]
      );
      const order = orderRows[0];

      for (const item of items) {
        await client.query(
          'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1,$2,$3,$4)',
          [order.id, item.product_id, item.quantity, item.price]
        );
        await client.query(
          'UPDATE products SET stock = stock - $1 WHERE id = $2',
          [item.quantity, item.product_id]
        );
      }

      await client.query('COMMIT');
      res.status(201).json(order);
    } catch (err) {
      await client.query('ROLLBACK');
      res.status(400).json({ error: err.message });
    } finally {
      client.release();
    }
  }
);

router.patch(
  '/:id/status',
  [param('id').isInt({ min: 1 }), body('status').isIn(['pending', 'processing', 'shipped', 'delivered', 'cancelled'])],
  validate,
  async (req, res) => {
    try {
      const { rows } = await pool.query(
        'UPDATE orders SET status = $1 WHERE id = $2 RETURNING *',
        [req.body.status, req.params.id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Order not found' });
      res.json(rows[0]);
    } catch (err) {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

module.exports = router;
