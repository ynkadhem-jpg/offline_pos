# COMPONENTS

Version: 1.0

---

# Purpose

This document defines every reusable UI component used throughout the application.

Never recreate an existing component.

If a component is used more than once, it should become reusable.

Business logic must never exist inside components.

---

# Naming Rules

Widgets should be named using nouns.

Examples:

CustomerCard

ProductCard

SaleCard

SummaryCard

SearchBar

StatusChip

SectionHeader

EmptyState

ConfirmationDialog

---

# Summary Card

Purpose

Display a business KPI.

Used In

Dashboard

Reports

Contains

• Leading icon

• Title

• Value

• Optional subtitle

• Optional trend

Interactions

Optional onTap.

Never contains menus.

---

# Customer Card

Purpose

Display a customer overview.

Contains

• Customer avatar/icon

• Customer name

• Phone number

• Remaining amount

• Current installment

• Payment status chip

• Overflow menu

Tap

Open customer details.

Overflow Menu

Edit

Delete

Future

Restore

Variables

customer.name

customer.phone

customer.remaining

customer.currentInstallment

customer.paymentStatus

---

# Product Card

Purpose

Display a product.

Contains

• Product icon

• Product name

• Product price

• Sales count

• Overflow menu

Never use product images.

---

# Sale Card

Purpose

Display one sale.

Contains

• Product name

• Original price

• Interest

• Total amount

• Remaining amount

• Expand button

Expanded

Installment table.

---

# Installment Table

Columns

Month

Due Date

Required Amount

Paid

Remaining

Status

Actions

Status

Paid

Partial

Upcoming

Overdue

Rows should remain touch friendly.

---

# Status Chip

Purpose

Display state.

States

Paid

Green

Partial

Orange

Overdue

Red

Upcoming

Blue

Deleted

Gray

All status chips use identical styling.

---

# Search Bar

Contains

Leading search icon.

Hint text.

Clear button.

Search is always visible.

---

# Filter Chips

Purpose

Quick filtering.

Single selection.

Scrollable.

Animated.

---

# Section Header

Contains

Title.

Optional subtitle.

Optional action button.

---

# Empty State

Contains

Illustration or icon.

Title.

Description.

Optional action.

Never show empty pages.

---

# Loading State

Use

CircularProgressIndicator

or

Skeleton

Never freeze UI.

---

# Error State

Contains

Error icon.

Friendly Arabic message.

Retry button.

Never expose exceptions.

---

# Confirmation Dialog

Contains

Title.

Description.

Cancel.

Confirm.

Destructive actions require confirmation.

---

# Money Text

Always use

${currency.format(value)} د.ع

Never place the currency before the number.

Never manually format separators.

---

# Date Text

Always use the project's existing formatter.

Never manually concatenate date strings.

---

# Action Button

Use FilledButton.

Icons are optional.

Text must be Arabic.

---

# Secondary Button

Use OutlinedButton.

---

# Destructive Button

Use FilledButton with the theme error color.

Always require confirmation before executing.

---

# Reuse Rules

Before creating a new widget:

Check whether an existing reusable component can be used.

Never duplicate layouts.

Prefer composition over duplication.

---

# AI Rules

Never invent new components.

Reuse existing components whenever possible.

If a new component is required, ensure it is generic enough for future reuse.

Never embed business logic inside reusable widgets.

Components receive data only.

Business rules remain in services and DAOs.