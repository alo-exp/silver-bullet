# Tech Stack Detection

Used in Phase 2.3 of silver-init. Based on which manifest file was found, set the tech stack string:

- `package.json` → Read it and check for key dependencies (e.g., "react", "next", "express", "vue", "angular", "typescript", "bun", "deno"). Compose a string like "Node.js / TypeScript / React" based on what is found.
- `pyproject.toml` → "Python" plus key dependencies (Django, Flask, FastAPI, etc.)
- `Cargo.toml` → "Rust" plus key dependencies (axum, tokio, actix-web, etc.)
- `go.mod` → "Go" plus key dependencies (gin, echo, fiber, etc.)
- `pom.xml` → "Java / Maven" plus key deps (Spring Boot, Quarkus, etc.)
- `build.gradle` → "Java / Gradle" or "Kotlin / Gradle" (check for `kotlin` plugin)
- `build.gradle.kts` → "Kotlin / Gradle" plus key deps (Ktor, Spring, etc.)
- `Gemfile` → "Ruby" plus key gems (Rails, Sinatra, Roda, etc.)
- `composer.json` → "PHP" plus key packages (Laravel, Symfony, WordPress, etc.)
- `mix.exs` → "Elixir" plus key deps (Phoenix, Ecto, etc.)
- `Package.swift` → "Swift" plus key deps
- `*.csproj` / `*.sln` → ".NET / C#" plus target framework (net8.0, net9.0, etc.)
- `pubspec.yaml` → "Dart / Flutter"
- If none found → "Unknown — please specify"
