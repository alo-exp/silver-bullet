const request = require('supertest');
const { app } = require('../server');

describe('Todo API', () => {
  describe('GET /api/todos', () => {
    it('returns empty array when no todos', async () => {
      const res = await request(app).get('/api/todos');
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });
  });

  describe('POST /api/todos', () => {
    it('creates a new todo', async () => {
      const res = await request(app)
        .post('/api/todos')
        .send({ title: 'New todo' });
      expect(res.status).toBe(201);
      expect(res.body.title).toBe('New todo');
      expect(res.body.id).toBeDefined();
    });

    it('returns 400 when title missing', async () => {
      const res = await request(app)
        .post('/api/todos')
        .send({});
      expect(res.status).toBe(400);
    });
  });

  describe('GET /api/todos/:id', () => {
    it('returns 404 for non-existent todo', async () => {
      const res = await request(app).get('/api/todos/9999');
      expect(res.status).toBe(404);
    });
  });

  describe('PUT /api/todos/:id', () => {
    it('returns 404 for non-existent todo', async () => {
      const res = await request(app)
        .put('/api/todos/9999')
        .send({ title: 'New title' });
      expect(res.status).toBe(404);
    });
  });

  describe('DELETE /api/todos/:id', () => {
    it('returns 404 for non-existent todo', async () => {
      const res = await request(app).delete('/api/todos/9999');
      expect(res.status).toBe(404);
    });
  });

  describe('GET /api/health', () => {
    it('returns health status', async () => {
      const res = await request(app).get('/api/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
    });
  });
});
