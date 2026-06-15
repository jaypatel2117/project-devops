import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { useCart } from '../context/CartContext';
import { createOrder } from '../api';
import './Cart.css';

export default function Cart() {
  const { items, total, removeFromCart, updateQty, clearCart } = useCart();
  const navigate = useNavigate();
  const [form, setForm] = useState({ customer_name: '', customer_email: '' });
  const [submitting, setSubmitting] = useState(false);

  async function handleCheckout(e) {
    e.preventDefault();
    if (!items.length) return;
    setSubmitting(true);
    try {
      await createOrder({
        ...form,
        items: items.map((i) => ({ product_id: i.id, quantity: i.quantity, price: i.price })),
      });
      clearCart();
      toast.success('Order placed successfully!');
      navigate('/orders');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed to place order');
    } finally {
      setSubmitting(false);
    }
  }

  if (!items.length) {
    return (
      <main className="cart-page">
        <div className="container">
          <h1>Your Cart</h1>
          <div className="empty-cart">
            <span>🛒</span>
            <p>Your cart is empty.</p>
            <button className="btn-primary" onClick={() => navigate('/')}>Browse Products</button>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className="cart-page">
      <div className="container">
        <h1>Your Cart</h1>
        <div className="cart-layout">
          <div className="cart-items">
            {items.map((item) => (
              <div key={item.id} className="cart-item">
                <img
                  src={item.image_url}
                  alt={item.name}
                  onError={(e) => { e.target.src = `https://via.placeholder.com/80?text=${encodeURIComponent(item.name)}`; }}
                />
                <div className="cart-item-info">
                  <h4>{item.name}</h4>
                  <p className="cart-item-price">${parseFloat(item.price).toFixed(2)}</p>
                </div>
                <div className="cart-item-qty">
                  <button onClick={() => updateQty(item.id, item.quantity - 1)}>−</button>
                  <span>{item.quantity}</span>
                  <button onClick={() => updateQty(item.id, item.quantity + 1)}>+</button>
                </div>
                <p className="cart-item-subtotal">${(parseFloat(item.price) * item.quantity).toFixed(2)}</p>
                <button className="btn-remove" onClick={() => removeFromCart(item.id)}>✕</button>
              </div>
            ))}
          </div>

          <div className="cart-summary">
            <h3>Order Summary</h3>
            <div className="summary-row">
              <span>Subtotal</span>
              <span>${total.toFixed(2)}</span>
            </div>
            <div className="summary-row">
              <span>Shipping</span>
              <span className="free">Free</span>
            </div>
            <div className="summary-row total">
              <span>Total</span>
              <span>${total.toFixed(2)}</span>
            </div>

            <form onSubmit={handleCheckout} className="checkout-form">
              <h4>Customer Details</h4>
              <input
                type="text"
                placeholder="Full name"
                required
                value={form.customer_name}
                onChange={(e) => setForm({ ...form, customer_name: e.target.value })}
              />
              <input
                type="email"
                placeholder="Email address"
                required
                value={form.customer_email}
                onChange={(e) => setForm({ ...form, customer_email: e.target.value })}
              />
              <button type="submit" className="btn-primary" disabled={submitting}>
                {submitting ? 'Placing order…' : 'Place Order'}
              </button>
            </form>
          </div>
        </div>
      </div>
    </main>
  );
}
