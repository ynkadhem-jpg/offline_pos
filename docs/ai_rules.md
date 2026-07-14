# AI Rules - Offline POS

## Project Overview

This project is an offline Flutter application for installment sales management.

Technology stack:

- Flutter
- Material 3
- Drift ORM
- SQLite
- Android First
- No Backend
- Arabic UI
- English Code
- IBM Plex Sans Arabic

---

# General Rules

1. Never recreate existing architecture.
2. Never recreate AppDatabase.
3. Never recreate Drift tables.
4. Never modify unrelated files.
5. Implement only the current task.
6. Keep commits small and focused.
7. Prefer clean, readable, maintainable code.
8. Do not add packages unless explicitly required.
9. Ask for clarification if requirements are ambiguous.
10. Do not introduce new architecture without approval.

---

# Coding Rules

- English for code.
- Arabic for UI.
- Use Material 3.
- Use existing Design System.
- Never hardcode colors.
- Never hardcode spacing.
- Reuse ThemeData.
- Follow Flutter lints.

---
## Money Formatting Rules

- All displayed monetary values must use the existing NumberFormat instance.
- Display every monetary value as:
  ${currency.format(value)} د.ع
- Keep money formatting consistent across the entire application.
- Do not format monetary values inside the database or business logic.
- Money formatting is a UI concern only.

---

# Drift Rules

- Use the existing AppDatabase.
- Use existing generated files.
- Prefer Companion objects for inserts.
- Do not recreate database.g.dart.
- Do not create duplicate DAOs.
- Keep queries efficient.
- Use Streams where appropriate.

---

# Task Rules

Before writing code:

1. Read PROJECT.md.
2. Read tasks.md.
3. Read PROJECT_LOGIC.md (if available).
4. Read database.dart.
5. Understand the current task.
6. Explain assumptions.
7. Wait for approval if requested.

---

# Scope Rules

Only modify files required by the current task.

Never refactor unrelated code.

Never implement future tasks early.

---

# Documentation

When a task is completed:

- Explain what changed.
- Explain why.
- Confirm the Definition of Done.

---

# Goal

Build a production-ready offline POS application with clean architecture, maintainable code, and consistent implementation across all tasks.