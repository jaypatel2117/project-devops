import React, { useEffect, useState } from 'react';
import { getProducts, getCategories } from '../api';
import ProductCard from '../components/ProductCard';
import './Home.css';

export default function Home() {
  const [products, setProducts]     = useState([]);
  const [categories, setCategories] = useState([]);
  const [category, setCategory]     = useState('');
  const [search, setSearch]         = useState('');
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState('');

  useEffect(() => {
    getCategories()
      .then((r) => setCategories(r.data))
      .catch(() => {});
  }, []);

  useEffect(() => {
    setLoading(true);
    setError('');
    getProducts({ category: category || undefined, search: search || undefined })
      .then((r) => setProducts(r.data))
      .catch(() => setError('Failed to load products. Is the backend running?'))
      .finally(() => setLoading(false));
  }, [category, search]);

  return (
    <main className="home">
      <section className="hero">
        <div className="container">
          <h1>Welcome to <span>ShopECS</span></h1>
          <p>A full-stack retail app running on <strong>AWS ECS Fargate</strong> with <strong>RDS PostgreSQL</strong>, deployed via a <strong>CI/CD pipeline</strong> built with Terraform.</p>
        </div>
      </section>

      <div className="container">
        <div className="filters">
          <input
            className="search-input"
            type="text"
            placeholder="Search products…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <div className="category-chips">
            <button
              className={`chip ${category === '' ? 'active' : ''}`}
              onClick={() => setCategory('')}
            >
              All
            </button>
            {categories.map((c) => (
              <button
                key={c}
                className={`chip ${category === c ? 'active' : ''}`}
                onClick={() => setCategory(c)}
              >
                {c}
              </button>
            ))}
          </div>
        </div>

        {loading && <div className="status-msg">Loading products…</div>}
        {error   && <div className="status-msg error">{error}</div>}

        {!loading && !error && (
          <>
            <p className="result-count">{products.length} product{products.length !== 1 ? 's' : ''} found</p>
            <div className="product-grid">
              {products.map((p) => <ProductCard key={p.id} product={p} />)}
            </div>
            {products.length === 0 && (
              <div className="status-msg">No products match your filters.</div>
            )}
          </>
        )}
      </div>
    </main>
  );
}
