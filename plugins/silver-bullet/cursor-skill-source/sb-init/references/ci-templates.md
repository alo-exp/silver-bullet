# CI Workflow Templates

Use these templates in Phase 3.2.5 based on the detected stack. Write to `.github/workflows/ci.yml`.

## Node.js (package.json found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint --if-present
      - run: npm run typecheck --if-present
      - run: npm test --if-present
```

## Python (pyproject.toml found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -e ".[dev]" || pip install -e .
      - run: ruff check . || true
      - run: mypy . || true
      - run: pytest
```

## Rust (Cargo.toml found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cargo clippy
      - run: cargo test
```

## Go (go.mod found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: stable }
      - run: go vet ./...
      - run: go test ./...
```

## Java / Maven (pom.xml found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: temurin }
      - run: ./mvnw --no-transfer-progress verify
```

## Java / Kotlin — Gradle (build.gradle or build.gradle.kts found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: temurin }
      - run: ./gradlew check
```

## Ruby (Gemfile found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { bundler-cache: true }
      - run: bundle exec rubocop --parallel || true
      - run: bundle exec rspec
```

## PHP (composer.json found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.3', coverage: none }
      - run: composer install --no-progress --prefer-dist
      - run: composer run lint || true
      - run: composer run test
```

## .NET / C# (*.csproj or *.sln found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.x' }
      - run: dotnet build --no-incremental
      - run: dotnet test --no-build
```

## Elixir (mix.exs found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with: { elixir-version: '1.17', otp-version: '27' }
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix credo --strict || true
      - run: mix test
```

## Swift (Package.swift found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift build
      - run: swift test
```

## Dart / Flutter (pubspec.yaml found)

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

## Other / Unknown Stack

Prompt user to specify verify commands. Store in `.silver-bullet.json` under `"verify_commands": ["cmd1", "cmd2"]`.
