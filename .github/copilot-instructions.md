# GitHub Copilot Instructions — Farmácia Boa Vista PDV API

## Project context

This repository contains the **Point-of-Sale (PDV) API** for the Boa Vista pharmacy system.
The API runs on **Azure App Service** and is the backend for all checkout, inventory, and sales operations.

---

## Tech stack

| Layer | Technology |
|---|---|
| Language | Python 3.12 |
| Framework | FastAPI |
| Database | Azure SQL (via `pyodbc` / `SQLAlchemy`) |
| CI/CD | GitHub Actions |
| Testing | pytest |
| Secrets | Azure Key Vault |

---

## Code style

- **Variables and functions:** `snake_case`
- **Classes:** `PascalCase`
- **Type hints are mandatory** on every function signature — parameters and return types.
- Prefer explicit over implicit: avoid `*args` and `**kwargs` unless truly generic.
- Maximum line length: **100 characters**.
- Use `pydantic` models (`BaseModel`) for all request and response schemas.

```python
# ✅ correct
def calculate_total(unit_price: float, quantity: int) -> float:
    return unit_price * quantity

# ❌ wrong — missing type hints
def calculate_total(unit_price, quantity):
    return unit_price * quantity
```

---

## Security rules

1. **Never commit secrets.** Passwords, connection strings, API keys, and certificates must be
   retrieved exclusively from **Azure Key Vault** at runtime. Do not hardcode them, do not put
   them in `.env` files tracked by git.

2. **Every public endpoint requires JWT authentication.** Use FastAPI's `Depends` mechanism with
   a reusable `get_current_user` dependency that validates the Bearer token.

3. **Never use `eval()` or any form of dynamic code execution** (`exec()`, `compile()`,
   `importlib` dynamic imports of untrusted input, etc.). This is a hard rule with no exceptions.

4. Validate and sanitize all user input through Pydantic schemas before it reaches business logic
   or the database layer.

5. Use parameterized queries only — never build SQL strings with string concatenation or f-strings.

```python
# ✅ correct — JWT dependency on every public route
@router.get("/sales/{sale_id}", response_model=SaleResponse)
async def get_sale(
    sale_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SaleResponse:
    ...

# ❌ forbidden
result = eval(user_provided_expression)
```

---

## Project structure

Follow this layout when creating new modules:

```
app/
  api/
    v1/
      routes/        # FastAPI routers, one file per domain
  core/
    config.py        # Settings loaded from Key Vault / env vars
    security.py      # JWT helpers, get_current_user dependency
  db/
    models.py        # SQLAlchemy ORM models
    session.py       # Async engine and session factory
  schemas/           # Pydantic request/response models
  services/          # Business logic, no HTTP concerns
tests/
  unit/
  integration/
.github/
  workflows/
```

---

## Testing

- Every new service function must have at least one `pytest` unit test.
- Use `pytest-asyncio` for async endpoints and services.
- Mock external dependencies (Azure SQL, Key Vault) with `pytest-mock` or `unittest.mock`.
- Test file naming: `test_<module_name>.py`.
- Minimum coverage target: **80 %** on `app/services/`.

---

## GitHub Actions

- Workflows live in `.github/workflows/`.
- The CI pipeline must run `pytest` and a `ruff` lint check on every push and pull request.
- Secrets in workflows must reference GitHub Secrets (which are themselves populated from
  Azure Key Vault) — never inline values.

---

## Commit conventions (Conventional Commits)

All commit messages must follow the **Conventional Commits** specification written in **English**:

```
<type>(optional scope): <short description>

[optional body]

[optional footer(s)]
```

### Allowed types

| Type | When to use |
|---|---|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation changes only |
| `style` | Formatting, missing semicolons — no logic change |
| `refactor` | Code change that is neither a fix nor a feature |
| `test` | Adding or updating tests |
| `chore` | Build process, dependency updates, tooling |
| `ci` | Changes to CI/CD configuration |
| `perf` | Performance improvements |
| `revert` | Reverting a previous commit |

### Examples

```
feat(sales): add discount calculation endpoint
fix(auth): handle expired JWT tokens correctly
test(inventory): add unit tests for stock deduction service
chore: upgrade fastapi to 0.111.0
```

### Rules

- Subject line in **lowercase**, imperative mood, no period at the end.
- Maximum subject line length: **72 characters**.
- Breaking changes must include `!` after the type/scope and a `BREAKING CHANGE:` footer.
