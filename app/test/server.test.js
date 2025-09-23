const request = require('supertest');
const app = require('../server');

describe('Happy Speller Server', () => {
  describe('GET /healthz', () => {
    it('should return status 200 and JSON with status ok', async () => {
      const response = await request(app).get('/healthz');
      expect(response.statusCode).toBe(200);
      expect(response.body).toEqual({ 
        status: 'ok', 
        timestamp: expect.any(String) 
      });
    });

    it('should return valid timestamp format', async () => {
      const response = await request(app).get('/healthz');
      const timestamp = new Date(response.body.timestamp);
      expect(timestamp).toBeInstanceOf(Date);
      expect(timestamp.getTime()).not.toBeNaN();
    });
  });

  describe('GET /api/version', () => {
    it('should return application version and name', async () => {
      const response = await request(app).get('/api/version');
      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('name', 'Happy Speller');
    });

    it('should return version from environment or default', async () => {
      const response = await request(app).get('/api/version');
      expect(typeof response.body.version).toBe('string');
      expect(response.body.version.length).toBeGreaterThan(0);
    });
  });

  describe('GET /', () => {
    it('should serve the main application HTML', async () => {
      const response = await request(app).get('/');
      expect(response.statusCode).toBe(200);
      expect(response.text).toContain('Happy Speller');
      expect(response.text).toContain('<!DOCTYPE html>');
    });

    it('should serve HTML with proper meta tags', async () => {
      const response = await request(app).get('/');
      expect(response.text).toContain('<meta charset="UTF-8">');
      expect(response.text).toContain('<meta name="viewport"');
    });

    it('should include CSS and JavaScript', async () => {
      const response = await request(app).get('/');
      expect(response.text).toContain('<style>');
      expect(response.text).toContain('<script>');
    });
  });

  describe('Static file serving', () => {
    it('should serve static files with correct content type', async () => {
      const response = await request(app).get('/');
      expect(response.statusCode).toBe(200);
      expect(response.headers['content-type']).toMatch(/html/);
    });

    it('should handle unknown static files gracefully', async () => {
      const response = await request(app).get('/nonexistent.js');
      expect(response.statusCode).toBe(200); // Should serve index.html for SPA
    });
  });

  describe('Security headers', () => {
    it('should have basic security headers', async () => {
      const response = await request(app).get('/healthz');
      expect(response.headers).toHaveProperty('x-content-type-options');
      expect(response.headers).toHaveProperty('x-frame-options');
    });

    it('should have helmet security middleware active', async () => {
      const response = await request(app).get('/');
      expect(response.headers).toHaveProperty('x-dns-prefetch-control');
    });
  });

  describe('CORS', () => {
    it('should handle CORS requests', async () => {
      const response = await request(app).get('/api/version');
      expect(response.headers).toHaveProperty('access-control-allow-origin');
    });

    it('should handle CORS preflight requests', async () => {
      const response = await request(app).options('/api/version');
      expect(response.statusCode).toBeLessThan(500);
    });
  });

  describe('Error handling', () => {
    it('should handle 404 for API routes', async () => {
      const response = await request(app).get('/api/nonexistent');
      expect(response.statusCode).toBe(200); // Should serve index.html for SPA
    });

    it('should handle invalid JSON gracefully', async () => {
      const response = await request(app)
        .post('/api/test')
        .send('invalid-json')
        .set('Content-Type', 'application/json');
      
      expect(response.statusCode).toBeLessThan(500);
    });
  });

  describe('Performance', () => {
    it('should respond to health check quickly', async () => {
      const start = Date.now();
      await request(app).get('/healthz');
      const duration = Date.now() - start;
      expect(duration).toBeLessThan(1000); // Should respond within 1 second
    });

    it('should handle concurrent requests', async () => {
      const promises = Array(10).fill().map(() => 
        request(app).get('/healthz')
      );
      
      const responses = await Promise.all(promises);
      responses.forEach(response => {
        expect(response.statusCode).toBe(200);
      });
    });
  });
});
