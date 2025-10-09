# Package Analysis Suite Split Plan

## Current (Monolithic)
```
package_analysis_suite/
├─ Collects packages (npm/cargo/hex/pypi)
├─ Extracts code snippets
├─ Quality analysis
├─ Architecture analysis  
└─ Code analysis
```

## New Architecture (4 Trios)

### 1. Package Service (Registry Only)
```
package_engine/          # Shared lib (collector, storage)
package_intelligence/    # Client NIF (fast local lookup)
package_central_service/ # Central daemon (NATS registry service)
```
**Purpose:** Package metadata, downloads, registry API

### 2. Quality Service
```
quality_engine/          # Shared lib ✅ EXISTS
quality_intelligence/    # Client NIF ❌ CREATE
quality_central_service/ # Central daemon ❌ CREATE
```
**Purpose:** Quality metrics, code smells, technical debt

### 3. Code Service
```
code_engine/             # Shared lib ✅ EXISTS
code_intelligence/       # Client NIF ❌ CREATE  
code_central_service/    # Central daemon ❌ CREATE
```
**Purpose:** Code parsing, AST analysis, control flow

### 4. Architecture Service
```
architecture_engine/     # Shared lib ✅ EXISTS
architecture_intelligence/ # Client NIF ❌ CREATE
architecture_central_service/ # Central daemon ❌ CREATE
```
**Purpose:** Architecture patterns, naming, structure

## Migration Steps

1. ✅ Extract package registry logic → package_engine
2. ❌ Create quality_intelligence (NIF)
3. ❌ Create code_intelligence (NIF)
4. ❌ Create architecture_intelligence (NIF)
5. ❌ Create 3 central services
6. ❌ Wire to Elixir
7. ❌ Deprecate package_analysis_suite

## Benefits
- Focused services (single responsibility)
- Parallel development
- Independent scaling
- Cleaner NATS subjects
