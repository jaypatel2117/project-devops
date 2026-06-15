import React from 'react';
import { useCart } from '../context/CartContext';
import './ProductCard.css';

export default function ProductCard({ product }) {
  const { addToCart } = useCart();

  return (
    <div className="product-card">
      <div className="product-img-wrap">
        <img
          src={product.image_url}
          alt={product.name}
          loading="lazy"
          onError={(e) => { e.target.src = `https://via.placeholder.com/400x240?text=${encodeURIComponent(product.name)}`; }}
        />
        <span className="product-category">{product.category}</span>
      </div>
      <div className="product-body">
        <h3 className="product-name">{product.name}</h3>
        <p className="product-desc">{product.description}</p>
        <div className="product-footer">
          <div>
            <span className="product-price">${parseFloat(product.price).toFixed(2)}</span>
            <span className={`product-stock ${product.stock < 10 ? 'low' : ''}`}>
              {product.stock > 0 ? `${product.stock} in stock` : 'Out of stock'}
            </span>
          </div>
          <button
            className="btn-add"
            disabled={product.stock === 0}
            onClick={() => addToCart(product)}
          >
            Add to cart
          </button>
        </div>
      </div>
    </div>
  );
}
