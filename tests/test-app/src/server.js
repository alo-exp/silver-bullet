const express = require('express');
const path = require('path');
const todosRouter = require('./routes/todos');

const app = express();
const PORT = process.env.PORT || 3456;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.use('/api/todos', todosRouter);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server (only when run directly, not when imported for testing)
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Todo app running at http://localhost:${PORT}`);
  });
}

module.exports = app;
