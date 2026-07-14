# Navigation

Version: 1.0

---

# Purpose

Defines the application's navigation structure.

Every screen must follow this navigation.

Do not introduce additional navigation patterns.

---

# Platform

Android Tablet

RTL

Landscape First

---

# Navigation Type

Permanent NavigationRail (Sidebar).

Do not use BottomNavigationBar.

The NavigationRail remains visible on all main pages.

---

# Main Navigation

1. Dashboard

2. Customers

3. Products

4. Reports

5. Backup

6. Settings

Future

License

---

# Dashboard

Purpose

Business overview.

---

# Customers

Purpose

Manage customers.

Open customer details.

---

# Products

Purpose

Manage products.

---

# Reports

Purpose

Financial reports.

Sales history.

Statistics.

---

# Backup

Purpose

Backup

Restore

Google Drive

---

# Settings

Purpose

Application settings.

---

# Customer Details

Not shown in NavigationRail.

Opened from Customers.

Back returns to Customers.

---

# Dialogs

Never appear in navigation.

Always modal.

---

# Navigation Rules

Only one page may be active.

Navigation should preserve page state.

Use IndexedStack where appropriate.

Avoid rebuilding pages unnecessarily.

---

# Future

License screen may be added later.

No redesign should be required.