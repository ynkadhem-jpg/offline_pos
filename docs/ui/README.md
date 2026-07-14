# Offline POS UI Documentation

## Purpose

This folder is the official UI specification for the Offline POS application.

Every UI implementation must follow these documents before writing Flutter code.

This documentation defines:

- Visual style
- Layout
- Navigation
- Components
- Screen behavior
- User interactions

Business logic is NOT defined here.

---

# Documentation Order

Always read documents in this order:

1. DESIGN_SYSTEM.md
2. COMPONENTS.md
3. NAVIGATION.md
4. Screen Specification
5. Reference Image

Example:

DESIGN_SYSTEM.md

↓

COMPONENTS.md

↓

customers.md

↓

reference/customers.png

↓

Flutter implementation

---

# Folder Structure

ui/

├── README.md

├── DESIGN_SYSTEM.md

├── COMPONENTS.md

├── NAVIGATION.md

│

├── reference/

│ ├── dashboard.png

│ ├── customers.png

│ ├── customer_details.png

│ ├── products.png

│ ├── reports.png

│ ├── backup.png

│ └── settings.png

│

└── screens/

├── dashboard.md

├── customers.md

├── customer_details.md

├── products.md

├── reports.md

├── backup.md

└── settings.md

---

# Implementation Rules

Reference images define:

- Layout
- Visual hierarchy
- Spacing
- Card placement
- General appearance

Markdown files define:

- Components
- Variables
- Buttons
- Menus
- Navigation
- States
- Required widgets

Never infer business logic from UI.

---

# Flutter Rules

UI implementation must:

- Use Material 3
- Use ThemeData
- Support RTL
- Reuse existing widgets
- Reuse existing DAOs
- Reuse existing services

Do not modify business logic.

Do not modify database schema.

Do not introduce new architecture.

Do not add packages unless explicitly required.

---

# UI Philosophy

The application is a professional business application.

It is NOT a social app.

It is NOT an e-commerce app.

It is NOT a consumer application.

Design inspiration:

- ERP systems
- CRM systems
- Accounting software
- Modern dashboard applications

The interface should feel:

- Clean
- Spacious
- Fast
- Professional
- Easy to scan
- Optimized for tablets

---

# AI Instructions

Before implementing any screen:

1. Read the Design System.
2. Read the screen specification.
3. Review the reference image.
4. Reuse existing project architecture.
5. Implement only the requested screen.

Never redesign the application independently.

If something is missing from the specification,
ask for clarification instead of inventing behavior.