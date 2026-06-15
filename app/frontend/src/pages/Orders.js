import React, { useEffect, useState } from 'react';
import { getOrders } from '../api';
import './Orders.css';

const STATUS_COLOR = {
  pending:    '#f59e0b',
  processing: '#3b82f6',
  shipped:    '#8b5cf6',
  delivered:  '#10b981',
  cancelled:  '#ef4444',
};

export default function Orders() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]   = useState('');

  useEffect(() => {
    getOrders()
      .then((r) => setOrders(r.data))
      .catch(() => setError('Failed to load orders.'))
      .finally(() => setLoading(false));
  }, []);

  return (
    <main className="orders-page">
      <div className="container">
        <h1>Order History</h1>

        {loading && <div className="status-msg">Loading orders…</div>}
        {error   && <div className="status-msg error">{error}</div>}

        {!loading && !error && orders.length === 0 && (
          <div className="status-msg">No orders yet. Start shopping!</div>
        )}

        <div className="orders-list">
          {orders.map((order) => (
            <div key={order.id} className="order-card">
              <div className="order-header">
                <div>
                  <h3>Order #{order.id}</h3>
                  <p className="order-meta">
                    {order.customer_name} · {order.customer_email}
                  </p>
                  <p className="order-date">
                    {new Date(order.created_at).toLocaleDateString('en-CA', {
                      year: 'numeric', month: 'long', day: 'numeric',
                      hour: '2-digit', minute: '2-digit',
                    })}
                  </p>
                </div>
                <div className="order-right">
                  <span
                    className="order-status"
                    style={{ background: STATUS_COLOR[order.status] + '22', color: STATUS_COLOR[order.status] }}
                  >
                    {order.status}
                  </span>
                  <p className="order-total">${parseFloat(order.total_amount).toFixed(2)}</p>
                </div>
              </div>

              {order.items && order.items.length > 0 && (
                <div className="order-items">
                  {order.items.map((item, idx) => (
                    <div key={idx} className="order-item-row">
                      <span className="oi-name">{item.name}</span>
                      <span className="oi-qty">×{item.quantity}</span>
                      <span className="oi-price">${(parseFloat(item.price) * item.quantity).toFixed(2)}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
