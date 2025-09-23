const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
// Removed unused fs require

const app = express();
const port = process.env.PORT || 8080;

// Security middleware
app.use(helmet());
app.use(cors());

// JSON parser with sane limit (reduced from 10mb to 1mb)
app.use(express.json({ limit: '1mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Health endpoint
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API endpoint to get app version
app.get('/api/version', (req, res) => {
  res.json({ version: process.env.APP_VERSION || '1.0.0', name: 'Happy Speller' });
});

// Serve the main application
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error handling middleware (keep 4 args for Express)
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, _next) => {
  // Map body-parser errors to proper status codes
  if (err?.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Payload too large' });
  }
  if (err instanceof SyntaxError && 'body' in err) {
    return res.status(400).json({ error: 'Invalid JSON' });
  }
  // Fallback for other errors
  console.error(err.stack);
  return res.status(500).json({ error: 'Something went wrong!' });
});

// Only start the server if not in test environment
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`Happy Speller server running on port ${port}`);
  });
}

// Export the app for testing
module.exports = app;
