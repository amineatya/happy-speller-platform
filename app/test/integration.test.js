const request = require('supertest');
const app = require('../server');

describe('Happy Speller Integration Tests', () => {
  let agent;

  beforeAll(() => {
    agent = request.agent(app);
  });

  describe('Application Flow', () => {
    it('should serve the complete application workflow', async () => {
      // 1. Load the main application
      const homeResponse = await agent.get('/');
      expect(homeResponse.statusCode).toBe(200);
      expect(homeResponse.text).toContain('Happy Speller');
      expect(homeResponse.text).toContain('Words');
      expect(homeResponse.text).toContain('Math');

      // 2. Check health endpoint
      const healthResponse = await agent.get('/healthz');
      expect(healthResponse.statusCode).toBe(200);
      expect(healthResponse.body.status).toBe('ok');

      // 3. Get version info
      const versionResponse = await agent.get('/api/version');
      expect(versionResponse.statusCode).toBe(200);
      expect(versionResponse.body).toHaveProperty('name', 'Happy Speller');
    });

    it('should handle SPA routing correctly', async () => {
      const routes = ['/words', '/math', '/settings', '/nonexistent'];
      
      for (const route of routes) {
        const response = await agent.get(route);
        expect(response.statusCode).toBe(200);
        expect(response.text).toContain('Happy Speller');
        expect(response.text).toContain('<!DOCTYPE html>');
      }
    });
  });

  describe('Content Validation', () => {
    it('should serve application with all required word sets', async () => {
      const response = await agent.get('/');
      
      // Check for word level buttons
      expect(response.text).toContain('Level 1');
      expect(response.text).toContain('Level 2');
      expect(response.text).toContain('Level 3');
      expect(response.text).toContain('Level 4');
      expect(response.text).toContain('Your Words');
    });

    it('should serve application with math activities', async () => {
      const response = await agent.get('/');
      
      // Check for math tiles
      expect(response.text).toContain('Count & Compare');
      expect(response.text).toContain('Add & Subtract');
      expect(response.text).toContain('Teen Numbers');
      expect(response.text).toContain('Measure & Data');
      expect(response.text).toContain('Geometry');
    });

    it('should include JavaScript application state', async () => {
      const response = await agent.get('/');
      
      // Check for application state and functionality
      expect(response.text).toContain('const state = {');
      expect(response.text).toContain('L1_sight_preprimer');
      expect(response.text).toContain('L2_cvc_short_vowels');
      expect(response.text).toContain('speechSynthesis');
    });

    it('should include proper CSS styling', async () => {
      const response = await agent.get('/');
      
      // Check for CSS variables and styling
      expect(response.text).toContain(':root {');
      expect(response.text).toContain('--primary:');
      expect(response.text).toContain('--secondary:');
      expect(response.text).toContain('.word-card');
      expect(response.text).toContain('.math-tile');
    });
  });

  describe('Accessibility Features', () => {
    it('should include accessibility attributes', async () => {
      const response = await agent.get('/');
      
      expect(response.text).toContain('aria-label=');
      expect(response.text).toContain('aria-live=');
      expect(response.text).toContain('aria-hidden=');
    });

    it('should support keyboard navigation', async () => {
      const response = await agent.get('/');
      
      // Check for keyboard-accessible elements
      expect(response.text).toContain('tabindex');
      expect(response.text).toMatch(/role\s*=/);
    });
  });

  describe('Responsive Design', () => {
    it('should include responsive CSS media queries', async () => {
      const response = await agent.get('/');
      
      expect(response.text).toContain('@media (max-width: 768px)');
      expect(response.text).toContain('@media (max-width: 480px)');
    });

    it('should include viewport meta tag', async () => {
      const response = await agent.get('/');
      
      expect(response.text).toContain('viewport');
      expect(response.text).toContain('width=device-width');
    });
  });

  describe('Performance Considerations', () => {
    it('should serve application quickly', async () => {
      const start = Date.now();
      const response = await agent.get('/');
      const duration = Date.now() - start;
      
      expect(response.statusCode).toBe(200);
      expect(duration).toBeLessThan(2000); // Should serve within 2 seconds
    });

    it('should handle multiple concurrent requests', async () => {
      const concurrentRequests = 20;
      const promises = Array(concurrentRequests).fill().map(() => 
        agent.get('/')
      );
      
      const responses = await Promise.all(promises);
      
      responses.forEach(response => {
        expect(response.statusCode).toBe(200);
        expect(response.text).toContain('Happy Speller');
      });
    });
  });

  describe('Error Resilience', () => {
    it('should handle malformed requests gracefully', async () => {
      const response = await agent
        .post('/')
        .send('invalid-data')
        .set('Content-Type', 'application/json');
      
      expect(response.statusCode).toBeLessThan(500);
    });

    it('should handle large payloads appropriately', async () => {
      const largePayload = 'x'.repeat(11 * 1024 * 1024); // 11MB (exceeds 10MB limit)
      
      const response = await agent
        .post('/api/test')
        .send(largePayload)
        .set('Content-Type', 'application/json');
      
      expect(response.statusCode).toBe(413); // Payload Too Large
    });
  });
});