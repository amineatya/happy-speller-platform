const request = require('supertest');
const { app } = require('../server');

describe('Happy Speller Server', () => {
  describe('GET /healthz', () => {
    it('should return status 200 and JSON with status ok', async () => {
      const response = await request(app).get('/healthz');
      expect(response.statusCode).toBe(200);
      expect(response.body).toEqual({ status: 'ok', timestamp: expect.any(String) });
    });
  });

  describe('GET /api/version', () => {
    it('should return application version', async () => {
      const response = await request(app).get('/api/version');
      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('name', 'Happy Speller');
    });
  });

  describe('GET /', () => {
    it('should serve the main application', async () => {
      const response = await request(app).get('/');
      expect(response.statusCode).toBe(200);
      expect(response.text).toContain('Happy Speller');
    });
  });
});
