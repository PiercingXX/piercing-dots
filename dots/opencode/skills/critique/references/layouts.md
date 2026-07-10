# Utility Layout Skeletons

## skeleton: wireframe-box
```html
<!-- Low-fidelity placeholder blocks -->
<div class="wf-box wf-box--hero" style="height:400px;background:#e5e5e5;display:flex;align-items:center;justify-content:center;">
  <span style="color:#999;font-family:monospace;font-size:13px;">HERO 1440×400</span>
</div>
<div class="wf-box wf-box--nav" style="height:60px;background:#d5d5d5;">
  <span style="color:#999;font-family:monospace;font-size:13px;">NAV</span>
</div>
```

## skeleton: critique-scorecard
```html
<table class="critique-table">
  <thead><tr><th>Dimension</th><th>Score (1–5)</th><th>Notes</th></tr></thead>
  <tbody>
    <tr><td>Philosophy</td><td>—</td><td><!-- notes --></td></tr>
    <tr><td>Hierarchy</td><td>—</td><td><!-- notes --></td></tr>
    <tr><td>Detail</td><td>—</td><td><!-- notes --></td></tr>
    <tr><td>Function</td><td>—</td><td><!-- notes --></td></tr>
    <tr><td>Innovation</td><td>—</td><td><!-- notes --></td></tr>
  </tbody>
</table>
```

## skeleton: annotation-layer
```html
<div class="annotation-wrap" style="position:relative;">
  <!-- Target element -->
  <div class="annotation" style="position:absolute;top:0;left:0;">
    <div class="annotation__line"></div>
    <div class="annotation__label"><!-- Note --></div>
  </div>
</div>
```
