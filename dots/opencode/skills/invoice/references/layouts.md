# Document Layout Skeletons

## skeleton: doc-header
```html
<header class="doc-header">
  <div class="doc-meta">
    <span class="doc-type"><!-- Document type --></span>
    <span class="doc-date"><!-- Date --></span>
    <span class="doc-status doc-status--draft">Draft</span>
  </div>
  <h1 class="doc-title"><!-- Title --></h1>
  <p class="doc-summary"><!-- 1-sentence executive summary --></p>
  <div class="doc-owners"><!-- Author(s) / Owner(s) --></div>
</header>
```

## skeleton: section-block
```html
<section class="doc-section">
  <h2 class="section-heading"><!-- Section heading --></h2>
  <div class="section-body">
    <!-- Prose, tables, or structured content -->
  </div>
</section>
```

## skeleton: data-table
```html
<table class="doc-table">
  <thead>
    <tr><th><!-- Column --></th><th><!-- Column --></th></tr>
  </thead>
  <tbody>
    <tr><td><!-- Cell --></td><td><!-- Cell --></td></tr>
  </tbody>
</table>
```

## skeleton: status-badge
```html
<span class="badge badge--green">On Track</span>
<span class="badge badge--amber">At Risk</span>
<span class="badge badge--red">Off Track</span>
```

## skeleton: okr-block
```html
<div class="okr">
  <div class="okr__objective">
    <h3><!-- Objective --></h3>
    <div class="okr__key-results">
      <div class="kr">
        <span class="kr__label">KR1</span>
        <span class="kr__text"><!-- Key result --></span>
        <span class="kr__progress">—%</span>
      </div>
    </div>
  </div>
</div>
```
