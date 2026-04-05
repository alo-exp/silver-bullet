const express = require('express');
const { getDb } = require('../db/database');

const router = express.Router();

// GET /api/todos — list all todos
router.get('/', (req, res) => {
  const db = getDb();
  const todos = db.prepare('SELECT * FROM todos ORDER BY created_at DESC').all();
  res.json(todos);
});

// GET /api/todos/:id — get single todo
router.get('/:id', (req, res) => {
  const db = getDb();
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return res.status(400).json({ error: 'Invalid todo ID' });
  }
  const todo = db.prepare('SELECT * FROM todos WHERE id = ?').get(id);
  if (!todo) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  res.json(todo);
});

// POST /api/todos — create a todo
router.post('/', (req, res) => {
  const { title } = req.body;
  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    return res.status(400).json({ error: 'Title is required' });
  }
  if (title.length > 500) {
    return res.status(400).json({ error: 'Title must be 500 characters or less' });
  }
  const db = getDb();
  const result = db.prepare('INSERT INTO todos (title) VALUES (?)').run(title.trim());
  const todo = db.prepare('SELECT * FROM todos WHERE id = ?').get(result.lastInsertRowid);
  res.status(201).json(todo);
});

// PUT /api/todos/:id — update a todo
router.put('/:id', (req, res) => {
  const db = getDb();
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return res.status(400).json({ error: 'Invalid todo ID' });
  }
  const existing = db.prepare('SELECT * FROM todos WHERE id = ?').get(id);
  if (!existing) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  const { title, completed } = req.body;
  const updates = {};
  if (title !== undefined) {
    if (typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({ error: 'Title cannot be empty' });
    }
    if (title.length > 500) {
      return res.status(400).json({ error: 'Title must be 500 characters or less' });
    }
    updates.title = title.trim();
  }
  if (completed !== undefined) {
    updates.completed = completed ? 1 : 0;
  }
  if (Object.keys(updates).length === 0) {
    return res.status(400).json({ error: 'No fields to update' });
  }
  const setClauses = Object.keys(updates).map(k => `${k} = ?`).join(', ');
  const values = [...Object.values(updates), id];
  db.prepare(`UPDATE todos SET ${setClauses} WHERE id = ?`).run(...values);
  const todo = db.prepare('SELECT * FROM todos WHERE id = ?').get(id);
  res.json(todo);
});

// DELETE /api/todos/:id — delete a todo
router.delete('/:id', (req, res) => {
  const db = getDb();
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return res.status(400).json({ error: 'Invalid todo ID' });
  }
  const result = db.prepare('DELETE FROM todos WHERE id = ?').run(id);
  if (result.changes === 0) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  res.status(204).send();
});

module.exports = router;
