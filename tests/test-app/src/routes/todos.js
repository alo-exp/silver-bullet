const express = require('express');
const { getDb } = require('../db/database');

const router = express.Router();

// Validates a due_date string: must match YYYY-MM-DD and be a real calendar date.
// JavaScript's Date constructor silently rolls over invalid days (e.g. 2025-02-30
// becomes 2025-03-02), so we round-trip the parsed date back to confirm it matches.
function isValidDueDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(value);
  if (isNaN(parsed.getTime())) return false;
  const yyyy = parsed.getUTCFullYear();
  const mm = String(parsed.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(parsed.getUTCDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}` === value;
}

// GET /api/todos — list all todos (supports ?overdue=true filter)
router.get('/', (req, res) => {
  const db = getDb();
  let query = 'SELECT * FROM todos';
  const params = [];

  if (req.query.overdue === 'true') {
    const today = new Date().toISOString().split('T')[0];
    query += ' WHERE due_date IS NOT NULL AND due_date < ? AND completed = 0';
    params.push(today);
  }

  query += ' ORDER BY created_at DESC';
  const todos = db.prepare(query).all(...params);
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
  const { title, due_date } = req.body;
  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    return res.status(400).json({ error: 'Title is required' });
  }
  if (title.length > 500) {
    return res.status(400).json({ error: 'Title must be 500 characters or less' });
  }
  if (due_date !== undefined && due_date !== null) {
    if (!isValidDueDate(due_date)) {
      return res.status(400).json({ error: 'due_date must be a valid date in YYYY-MM-DD format' });
    }
  }
  const db = getDb();
  const result = db.prepare('INSERT INTO todos (title, due_date) VALUES (?, ?)').run(title.trim(), due_date || null);
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
  const { title, completed, due_date } = req.body;
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
  if (due_date !== undefined) {
    if (due_date === null || due_date === '') {
      updates.due_date = null;
    } else {
      if (!isValidDueDate(due_date)) {
        return res.status(400).json({ error: 'due_date must be a valid date in YYYY-MM-DD format' });
      }
      updates.due_date = due_date;
    }
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
