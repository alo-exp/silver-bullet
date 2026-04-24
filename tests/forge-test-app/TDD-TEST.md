# TDD Test Scenario: Add Todo Completion Toggle

## Context
The todo app currently has:
- Add todo via POST /api/todos
- List todos via GET /api/todos
- No way to mark todos as completed

## TDD Workflow Test

### Step 1: RED - Write a failing test
Add a test that verifies marking a todo as completed works:

```javascript
describe('PUT /api/todos/:id/complete', () => {
  it('marks a todo as completed', async () => {
    // Create a todo
    const createRes = await request(app)
      .post('/api/todos')
      .send({ title: 'Test todo' });
    const todoId = createRes.body.id;

    // Mark as completed
    const res = await request(app)
      .put(\`/api/todos/\${todoId}\`)
      .send({ completed: true });
    
    expect(res.status).toBe(200);
    expect(res.body.completed).toBe(true);
  });
});
```

### Step 2: GREEN - Make the test pass
Implement the complete endpoint by updating the existing PUT route.

### Step 3: REFACTOR - Clean up code
Ensure the implementation is clean and follows Express conventions.

## Trigger for TDD skill
Keywords that should invoke TDD skill:
- "TDD"
- "test-driven"
- "write a failing test first"
- "add a new feature using tests"
