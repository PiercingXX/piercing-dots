# Media & Visual Layout Skeletons

## skeleton: poster-full-bleed
```html
<div class="poster" style="width:1200px;height:1600px;position:relative;">
  <div class="poster__bg"><!-- Background layer / image --></div>
  <div class="poster__content">
    <div class="poster__eyebrow"><!-- Label --></div>
    <h1 class="poster__title"><!-- Headline --></h1>
    <p class="poster__sub"><!-- Subtext --></p>
    <div class="poster__footer"><!-- Logo / date / URL --></div>
  </div>
</div>
```

## skeleton: carousel-slide
```html
<div class="slide" style="width:1080px;height:1080px;">
  <div class="slide__number">01</div>
  <h2 class="slide__title"><!-- Slide headline --></h2>
  <p class="slide__body"><!-- Slide content --></p>
</div>
```

## skeleton: frame-sequence
```html
<div class="frame-strip">
  <div class="frame frame--1"><!-- State 1 --></div>
  <div class="frame frame--2"><!-- State 2 --></div>
  <div class="frame frame--3"><!-- State 3 --></div>
</div>
```

## skeleton: sprite-grid
```html
<div class="sprite-sheet" style="display:grid;grid-template-columns:repeat(8,64px);">
  <div class="sprite" style="width:64px;height:64px;"><!-- Frame 0 --></div>
  <!-- repeat for each frame -->
</div>
```
