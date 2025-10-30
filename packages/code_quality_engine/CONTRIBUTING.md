# Contributing to Code Quality Engine

Thank you for your interest in contributing to the Code Quality Engine! This document provides guidelines and information for contributors.

## Development Setup

### Prerequisites

- Rust 1.70+ with Cargo
- Git
- (Optional) Nix for reproducible builds

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/mikkihugo/singularity-incubation.git
   cd singularity-incubation/packages/code_quality_engine
   ```

2. **Build the project**
   ```bash
   cargo build
   ```

3. **Run tests**
   ```bash
   cargo test
   ```

4. **Run clippy for linting**
   ```bash
   cargo clippy
   ```

## Development Workflow

### 1. Choose an Issue

- Check the [GitHub Issues](https://github.com/mikkihugo/singularity-incubation/issues) for tasks
- Look for issues labeled `good first issue` or `help wanted`
- Comment on the issue to indicate you're working on it

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

### 3. Make Changes

- Follow the existing code style
- Add tests for new functionality
- Update documentation as needed
- Run `cargo clippy` to check for linting issues

### 4. Testing

- Add unit tests for new functions
- Add integration tests for new features
- Ensure all existing tests pass: `cargo test`
- Run benchmarks if performance is affected: `cargo bench`

### 5. Documentation

- Update README.md for new features
- Add rustdoc comments for public APIs
- Update examples if needed

### 6. Commit

```bash
git add .
git commit -m "feat: add amazing new feature

- What the change does
- Why it's needed
- Any breaking changes"
```

Use conventional commit format:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation
- `refactor:` for code restructuring
- `test:` for test additions

### 7. Push and Create PR

```bash
git push origin your-branch-name
```

Then create a Pull Request on GitHub.

## Code Guidelines

### Rust Style

- Follow the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- Use `rustfmt` for formatting: `cargo fmt`
- Follow clippy suggestions: `cargo clippy`
- Use meaningful variable names
- Add documentation comments for public APIs

### Error Handling

- Use `Result<T, E>` for fallible operations
- Define custom error types when appropriate
- Provide meaningful error messages

### Testing

- Write unit tests for all public functions
- Use descriptive test names
- Test both success and failure cases
- Mock external dependencies when needed

### Performance

- Consider performance implications of changes
- Add benchmarks for performance-critical code
- Use appropriate data structures
- Avoid unnecessary allocations

## Architecture Guidelines

### Module Organization

- Keep modules focused on single responsibilities
- Use clear, descriptive module names
- Export only necessary public APIs

### Language Support

When adding support for new languages:

1. Add language parser to `parser_engine/languages/`
2. Update the language registry
3. Add language-specific rules
4. Update tests and documentation

### Analysis Features

When adding new analysis features:

1. Define the analysis trait
2. Implement the analysis logic
3. Add configuration options
4. Update the orchestrator
5. Add tests and benchmarks

## Pull Request Process

1. **Title**: Use descriptive, concise titles
2. **Description**: Explain what and why
3. **Tests**: Ensure CI passes
4. **Review**: Address reviewer feedback
5. **Merge**: Squash merge when appropriate

## Community

- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Report bugs and request features
- **Discord**: Join our community chat

## License

By contributing, you agree that your contributions will be licensed under the MIT License.</content>
<parameter name="filePath">/home/mhugo/code/singularity/packages/code_quality_engine/CONTRIBUTING.md