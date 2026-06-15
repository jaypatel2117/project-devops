import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useCart } from '../context/CartContext';
import './Header.css';

export default function Header() {
  const { count } = useCart();
  const { pathname } = useLocation();

  return (
    <header className="header">
      <div className="container header-inner">
        <Link to="/" className="logo">
          <span className="logo-icon">🛒</span>
          <span className="logo-text">ShopECS</span>
          <span className="logo-badge">AWS Demo</span>
        </Link>
        <nav className="nav">
          <Link to="/" className={`nav-link ${pathname === '/' ? 'active' : ''}`}>Products</Link>
          <Link to="/orders" className={`nav-link ${pathname === '/orders' ? 'active' : ''}`}>Orders</Link>
          <Link to="/cart" className={`nav-link cart-link ${pathname === '/cart' ? 'active' : ''}`}>
            Cart
            {count > 0 && <span className="cart-badge">{count}</span>}
          </Link>
        </nav>
      </div>
    </header>
  );
}
