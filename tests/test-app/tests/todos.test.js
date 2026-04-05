const http = require('http');
const app = require('../src/server');
const { resetDb } = require('../src/db/database');

let server;
let baseUrl;

beforeAll((done) => {
  server = http.createServer(app);
  server.listen(0, () => {
    const port = server.address().port;
    baseUrl = `http://localhost:${port}`;
    done();
  });
});

afterAll((done) => {
  server.close(() => {
    resetDb();
    done();
  });
});

beforeEach(() => {
  // Reset database between tests for isolation
  resetDb();
});

async function api(path, options = {}) {
  const url = `${baseUrl}${path}`;
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  const body = res.status === 204 ? null : await res.json();
  return { status: res.status, body };
}

describe('GET /api/health', () => {
  test('returns ok status', async () => {
    const { status, body } = await api('/api/health');
    expect(status).toBe(200);
    expect(body.status).toBe('ok');
  });
});

describe('GET /api/todos', () => {
  test('returns empty array initially', async () => {
    const { status, body } = await api('/api/todos');
    expect(status).toBe(200);
    expect(body).toEqual([]);
  });

  test('returns todos after creation', async () => {
    await api('/api/todos', { method: 'POST', body: JSON.stringify({ title: 'Test todo' }) });
    const { status, body } = await api('/api/todos');
    expect(status).toBe(200);
    expect(body).toHaveLength(1);
    expect(body[0].title).toBe('Test todo');
  });
});

describe('POST /api/todos', () => {
  test('creates a todo with valid title', async () => {
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Buy groceries' }),
    });
    expect(status).toBe(201);
    expect(body.title).toBe('Buy groceries');
    expect(body.completed).toBe(0);
    expect(body.id).toBeDefined();
  });

  test('rejects empty title', async () => {
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: '' }),
    });
    expect(status).toBe(400);
    expect(body.error).toMatch(/title/i);
  });

  test('rejects missing title', async () => {
    const { status } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({}),
    });
    expect(status).toBe(400);
  });

  test('trims whitespace from title', async () => {
    const { body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: '  Buy milk  ' }),
    });
    expect(body.title).toBe('Buy milk');
  });

  test('rejects title over 500 characters', async () => {
    const { status } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'x'.repeat(501) }),
    });
    expect(status).toBe(400);
  });
});

describe('GET /api/todos/:id', () => {
  test('returns a specific todo', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Specific todo' }),
    });
    const { status, body } = await api(`/api/todos/${created.id}`);
    expect(status).toBe(200);
    expect(body.title).toBe('Specific todo');
  });

  test('returns 404 for nonexistent todo', async () => {
    const { status } = await api('/api/todos/9999');
    expect(status).toBe(404);
  });

  test('returns 400 for invalid id', async () => {
    const { status } = await api('/api/todos/abc');
    expect(status).toBe(400);
  });
});

describe('PUT /api/todos/:id', () => {
  test('updates todo title', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Original' }),
    });
    const { status, body } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({ title: 'Updated' }),
    });
    expect(status).toBe(200);
    expect(body.title).toBe('Updated');
  });

  test('toggles completed status', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Toggle me' }),
    });
    const { body } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({ completed: true }),
    });
    expect(body.completed).toBe(1);
  });

  test('returns 404 for nonexistent todo', async () => {
    const { status } = await api('/api/todos/9999', {
      method: 'PUT',
      body: JSON.stringify({ title: 'Nope' }),
    });
    expect(status).toBe(404);
  });

  test('rejects empty update body', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'No update' }),
    });
    const { status } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({}),
    });
    expect(status).toBe(400);
  });
});

describe('DELETE /api/todos/:id', () => {
  test('deletes an existing todo', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Delete me' }),
    });
    const { status } = await api(`/api/todos/${created.id}`, { method: 'DELETE' });
    expect(status).toBe(204);

    const { status: getStatus } = await api(`/api/todos/${created.id}`);
    expect(getStatus).toBe(404);
  });

  test('returns 404 for nonexistent todo', async () => {
    const { status } = await api('/api/todos/9999', { method: 'DELETE' });
    expect(status).toBe(404);
  });
});
