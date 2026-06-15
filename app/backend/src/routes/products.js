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
    const { category, search } = req.query;
    let query = 'SELECT * FROM products';
    const params = [];

    if (category && search) {
      query += ' WHERE category = $1 AND (name ILIKE $2 OR description ILIKE $2)';
      params.push(category, `%${search}%`);
    } else if (category) {
      query += ' WHERE category = $1';
      params.push(category);
    } else if (search) {
      query += ' WHERE name ILIKE $1 OR description ILIKE $1';
      params.push(`%${search}%`);
    }

    query += ' ORDER BY id';
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/categories', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT DISTINCT category FROM products ORDER BY category');
    res.json(rows.map((r) => r.category));
  } catch (err) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get(
  '/:id',
  param('id').isInt({ min: 1 }),
  validate,
  async (req, res) => {
    try {
      const { rows } = await pool.query('SELECT * FROM products WHERE id = $1', [req.params.id]);
      if (!rows.length) return res.status(404).json({ error: 'Product not found' });
      res.json(rows[0]);
    } catch (err) {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

module.exports = router;
