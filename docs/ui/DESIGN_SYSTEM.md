# Offline POS Design System

Version: 1.0

---

# Purpose

This document defines the official visual language of the Offline POS application.

Every screen, dialog, widget, card, table, and form must follow this document.

Do not redesign individual screens independently.

---

# Design Principles

The application is built for:

- Android Tablets
- Offline usage
- Single shop owner
- Daily intensive usage

The interface must prioritize:

- Speed
- Readability
- Simplicity
- Consistency

Never sacrifice usability for decoration.

---

# Design Inspiration

Target style:

- Modern ERP
- CRM Dashboard
- Accounting Software

Reference qualities:

- Clean
- Spacious
- Soft
- Minimal
- Professional

Avoid consumer application styling.

---

# Language

Application UI:

Arabic (RTL)

Code:

English

---

# Layout

Application uses a permanent Navigation Rail.

Structure:

Navigation Rail

↓

Page Header

↓

Scrollable Content

Every page must have enough white space.

Avoid crowded layouts.

---

# Grid System

Use an 8dp spacing system.

Spacing examples:

XS

Small

Medium

Large

Extra Large

Never use random spacing values.

Spacing must come from the project's design constants.

---

# Theme

Always use ThemeData.

Never hardcode:

- Colors
- Text styles
- Shadows
- Shapes

Use ColorScheme.

---

# Typography

Font:

IBM Plex Sans Arabic

Hierarchy:

Display

Headline

Title

Body

Label

Use ThemeData typography.

Never use arbitrary font sizes.

---

# Color Usage

Primary

Application accent color.

Secondary

Supporting actions.

Surface

Cards

Dialogs

Sheets

Background

Page background.

Success

Paid

Completed

Healthy state

Warning

Partial payment

Attention

Error

Delete

Failed

Overdue

Information

Neutral informational content.

Never hardcode color values.

---

# Icons

Use Material Symbols Rounded.

Never mix icon packs.

Use icons only where they improve understanding.

No decorative icons.

---

# Navigation Rail

Contains:

Dashboard

Customers

Products

Reports

Backup

Settings

Future:

License

Only one destination may be active.

---

# App Bar

Contains:

Page title

Optional subtitle

Optional primary action

Optional search

Avoid clutter.

---

# Cards

Cards are the primary content container.

Rules:

Rounded corners

Soft elevation

Comfortable padding

Consistent spacing

Cards should never touch each other directly.

---

# Summary Cards

Used on Dashboard.

Contains:

Icon

Title

Value

Optional trend

Entire card is clickable only if navigation exists.

---

# Customer Card

Contains:

Customer name

Phone

Remaining amount

Current installment

Payment status

Overflow menu

Tap:

Open customer details.

---

# Product Card

Contains:

Product icon

Product name

Price

Overflow menu

No product images.

Icons only.

---

# Sale Card

Contains:

Product

Original price

Interest

Total

Remaining

Expand button

Expanded state displays installments.

---

# Installment Table

Columns:

Month

Due Date

Required Amount

Paid

Remaining

Status

Actions

Status:

Paid

Partial

Upcoming

Overdue

Rows should remain readable.

---

# Buttons

Primary

FilledButton

Secondary

OutlinedButton

Low emphasis

TextButton

Danger

Error-colored FilledButton

Never create custom button designs unless globally approved.

---

# Search

Every searchable page starts with:

Search

↓

Filters

↓

Content

Search is always visible.

---

# Filters

Use Chips.

Never use dropdowns when chips improve usability.

Selected state must be obvious.

---

# Forms

Forms use:

Filled TextFields

Numeric keyboard where appropriate

Clear labels

Validation messages in Arabic

Required fields clearly indicated.

---

# Dialogs

Material 3 dialogs.

Rounded corners.

Primary action on the appropriate side for RTL.

Dangerous actions require confirmation.

---

# Empty States

Every list requires an Empty State.

Contains:

Illustration or icon

Title

Description

Optional action

Never display blank pages.

---

# Loading

Show progress indicators.

Never freeze the interface.

Avoid blocking dialogs.
---

# Error States

Friendly Arabic message.

Retry action when appropriate.

Never expose stack traces.

---

# Tables

Tablet optimized.

Readable spacing.

Touch friendly rows.

Consistent alignment.

---

# Money

Every monetary value must be displayed as:

${currency.format(value)} د.ع

Currency is always after the number.

Never before.

Never manually format separators.

---

# Dates

Use the project's existing formatter.

Never manually compose date strings.

---

# Animations

Material motion only.

Duration:

150–200 ms.

Subtle.

Never flashy.

---

# Accessibility

Touch targets:

Minimum 48dp.

Readable contrast.

Large typography.

Tablet friendly.

---

# Performance

Use lazy scrolling.

Avoid rebuilding entire pages.

Split reusable widgets.

---

# Reusable Components

Repeated UI should become reusable widgets.

Avoid duplicated layouts.

---

# RTL Rules

Entire application uses RTL.

Numbers remain LTR.

Tables remain readable.

Icons remain Material defaults.

---

# Business Logic

UI must never contain business logic.

All calculations come from:

DAOs

Services

Database

Never duplicate calculations in widgets.

---

# AI Rules

When implementing UI:

Read this document first.

Read the screen specification.

Read the reference image.

Reuse existing architecture.

Reuse ThemeData.

Reuse existing DAOs.

Do not invent fields.

Do not invent business rules.

Do not modify unrelated files.

Implement only the requested screen.

---

# Future Compatibility

The UI should support:

Dark Mode

Desktop

Larger tablets

Additional modules

without requiring redesign.