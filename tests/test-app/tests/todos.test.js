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

describe('Due date support', () => {
  test('creates a todo with a due date', async () => {
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'With due date', due_date: '2025-12-31' }),
    });
    expect(status).toBe(201);
    expect(body.due_date).toBe('2025-12-31');
  });

  test('creates a todo without a due date (null)', async () => {
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'No due date' }),
    });
    expect(status).toBe(201);
    expect(body.due_date).toBeNull();
  });

  test('rejects invalid due date format', async () => {
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Bad date', due_date: 'not-a-date' }),
    });
    expect(status).toBe(400);
    expect(body.error).toMatch(/due_date/i);
  });

  test('rejects rolled-over calendar date (e.g. 2025-02-30)', async () => {
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Overflow date', due_date: '2025-02-30' }),
    });
    expect(status).toBe(400);
    expect(body.error).toMatch(/due_date/i);
  });

  test('updates due date on existing todo', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Update me' }),
    });
    const { status, body } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({ due_date: '2025-06-15' }),
    });
    expect(status).toBe(200);
    expect(body.due_date).toBe('2025-06-15');
  });

  test('clears due date by setting to null', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Clear me', due_date: '2025-06-15' }),
    });
    const { status, body } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({ due_date: null }),
    });
    expect(status).toBe(200);
    expect(body.due_date).toBeNull();
  });

  test('returns due_date in GET /api/todos response', async () => {
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Check field', due_date: '2025-03-01' }),
    });
    const { body: todos } = await api('/api/todos');
    expect(todos[0]).toHaveProperty('due_date');
    expect(todos[0].due_date).toBe('2025-03-01');
  });

  test('returns due_date in GET /api/todos/:id response', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Single get', due_date: '2025-04-01' }),
    });
    const { body } = await api(`/api/todos/${created.id}`);
    expect(body.due_date).toBe('2025-04-01');
  });
});

describe('Overdue filter', () => {
  test('filters overdue todos', async () => {
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Overdue task', due_date: '2020-01-01' }),
    });
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Future task', due_date: '2099-12-31' }),
    });
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'No date task' }),
    });
    const { body } = await api('/api/todos?overdue=true');
    expect(body).toHaveLength(1);
    expect(body[0].title).toBe('Overdue task');
  });

  test('excludes completed overdue todos from filter', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Done overdue', due_date: '2020-01-01' }),
    });
    await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({ completed: true }),
    });
    const { body } = await api('/api/todos?overdue=true');
    expect(body).toHaveLength(0);
  });

  test('returns all todos without overdue param', async () => {
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Task 1', due_date: '2020-01-01' }),
    });
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Task 2', due_date: '2099-12-31' }),
    });
    const { body } = await api('/api/todos');
    expect(body).toHaveLength(2);
  });
});
