# Dashboard Screen

Version: 1.0

---

# Purpose

The Dashboard is the application's home screen.

It provides the shop owner with a quick overview of the business.

This screen is read-only.

No financial calculations are performed in the UI.

All values come from existing services or DAOs.

---

# Reference

Use:

reference/dashboard.png

This image is the visual source of truth.

Match the layout and spacing as closely as possible.

Do not copy pixel-by-pixel.

Adapt the design to Material 3.

---
# Visual Fidelity

The reference image has priority over this document.

If a conflict exists between the written specification and the reference image:

Follow the reference image.

The implementation should preserve:

- Overall layout
- Visual hierarchy
- Card proportions
- Alignment
- Spacing
- Component placement

Adapt the design to Material 3 without changing the overall appearance.
---

# Layout

Application Layout

Navigation Rail

↓

App Bar

↓

Scrollable Dashboard

The dashboard is vertically scrollable.

The Navigation Rail remains visible.

---

# Sections

Display sections in this order:

1. Summary Cards

2. Latest Sales

3. Revenue Chart

4. Upcoming Installments

5. Top Selling Products

6. Financial Summary

7. Installment Status Chart

---

# App Bar

Contains

Page title

Optional current date

Global search field

Optional notification button

Do not place business actions here.

---

# Summary Cards

Display four KPI cards.

Cards should have equal width.

Each card contains

Icon

Title

Value

Optional monthly trend

Cards

Total Profit

Total Sales

Customers

Remaining Balance

Values come from Reports DAO.

No calculations inside widgets.

---

# Latest Sales Card

Purpose

Display recent sales.

Contains

Customer name

Product name

Sale amount

Relative time

Maximum

5 items

Footer

View All

---

# Revenue Chart

Display revenue trend.

Line chart.

Responsive.

Uses aggregated data only.

Do not calculate totals inside the widget.

---

# Upcoming Installments

Display upcoming installments.

Each row contains

Customer

Due date

Amount

Status badge

Maximum

5 rows

Footer

View All

---

# Top Selling Products

Display products sorted by sales count.

Each row contains

Product icon

Product name

Sales count

Maximum

5 rows

No product images.

Use Material icons.

---

# Financial Summary

Contains small statistic cards.

Examples

Today's collections

Today's remaining amount

Today's sales count

Use existing report values.

---

# Installment Status Chart

Display installment distribution.

Categories

Paid

Partial

Overdue

Upcoming

Values come from reports.

No UI calculations.

---

# Empty State

Every section must support empty data.

Display

Icon

Arabic message

Optional action

Never leave blank space.

---

# Loading State

Use Material progress indicators.

Loading should be section-based.

Never block the entire screen.

---

# Error State

Display friendly Arabic message.

Optional retry button.

Never expose exceptions.

---

# Navigation

Tapping

Latest Sale

↓

Open customer details.

Tapping

Upcoming Installment

↓

Open customer details.

Tapping

View All

↓

Navigate to corresponding page.

---

# Money

Always display

${currency.format(value)} د.ع

Never display the currency before the value.

Never manually format separators.

---

# Dates

Use the project's existing formatter.

Never manually build date strings.

---

# Performance

All lists must be lazy.

Avoid rebuilding the whole page.

Split dashboard into reusable widgets.

---

# Reusable Widgets

SummaryCard

DashboardSection

LatestSaleTile

UpcomingInstallmentTile

FinancialMiniCard

ChartCard

StatusChip

SectionHeader

---

# AI Rules

Do not modify business logic.

Do not modify database.

Do not introduce Riverpod.

Do not create fake data.

Reuse existing ThemeData.

Reuse existing DAOs.

Reuse existing services.

Only implement the Dashboard screen.

Do not implement future screens.