# Content Layout Skeletons

## skeleton: article-hero
```html
<header class="article-hero">
  <div class="eyebrow"><!-- Category / Tag --></div>
  <h1><!-- Title --></h1>
  <p class="subtitle"><!-- 1-sentence summary --></p>
  <div class="byline"><!-- Author · Date · Read time --></div>
</header>
```

## skeleton: body-prose
```html
<article class="prose">
  <p class="lead"><!-- Opening hook paragraph --></p>
  <!-- H2 sections with prose + optional pull-quotes -->
  <blockquote class="pull-quote"><!-- Key insight --></blockquote>
  <h2><!-- Section heading --></h2>
  <p><!-- Body copy --></p>
</article>
```

## skeleton: callout-box
```html
<div class="callout callout--tip">
  <span class="callout__icon">→</span>
  <p><!-- Key takeaway or note --></p>
</div>
```

## skeleton: code-block
```html
<figure class="code-figure">
  <pre><code class="language-ts"><!-- code --></code></pre>
  <figcaption><!-- Description --></figcaption>
</figure>
```

## skeleton: table-of-contents
```html
<nav class="toc">
  <p class="toc__label">Contents</p>
  <ol>
    <li><a href="#s1"><!-- Section 1 --></a></li>
    <li><a href="#s2"><!-- Section 2 --></a></li>
  </ol>
</nav>
```
