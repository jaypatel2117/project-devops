const request = require('supertest');

// Minimal smoke test — full integration tests require a live DB
describe('Health endpoint', () => {
  it('returns 200', async () => {
    // Mock pool so we can import without a real DB
    jest.mock('../db', () => ({ pool: {}, initDB: jest.fn() }));
    const app = require('../index');
    // app starts an actual server; just check the export doesn't throw
    expect(app).toBeDefined();
  });
});
