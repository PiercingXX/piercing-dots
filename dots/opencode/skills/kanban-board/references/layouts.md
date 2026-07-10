# App UI Layout Skeletons

## skeleton: sidebar-shell
```html
<div class="app-shell">
  <nav class="sidebar">
    <div class="sidebar__brand"><!-- Logo --></div>
    <ul class="sidebar__nav">
      <li class="nav-item nav-item--active"><!-- Item --></li>
      <li class="nav-item"><!-- Item --></li>
    </ul>
  </nav>
  <main class="main-content"><!-- Page content --></main>
</div>
```

## skeleton: stats-row
```html
<div class="stats-row">
  <div class="stat-card">
    <div class="stat-card__value">—</div>
    <div class="stat-card__label"><!-- Metric name --></div>
    <div class="stat-card__delta stat-card__delta--up">↑ —%</div>
  </div>
  <!-- repeat 3–4 cards -->
</div>
```

## skeleton: data-table
```html
<div class="table-wrapper">
  <table>
    <thead><tr><th><!-- Col --></th></tr></thead>
    <tbody>
      <tr><td><!-- Cell --></td></tr>
    </tbody>
  </table>
</div>
```

## skeleton: card-grid
```html
<div class="card-grid">
  <div class="card">
    <div class="card__header"><!-- Title + actions --></div>
    <div class="card__body"><!-- Content --></div>
    <div class="card__footer"><!-- Meta / status --></div>
  </div>
</div>
```

## skeleton: mobile-screen
```html
<div class="phone-frame">
  <div class="status-bar"><!-- 9:41 · signal · battery --></div>
  <div class="screen-content"><!-- App screen --></div>
  <div class="home-indicator"></div>
</div>
```
