# epub.yazi

Plugin for [Yazi](https://github.com/sxyazi/yazi) to preview epub file

```linux
git clone https://github.com/DreamMaoMao/epub.yazi.git ~/.config/yazi/plugins/epub.yazi
```

then include it in your `yazi.toml` to use:

```toml
[plugin]
prepend_previewers = [
  { name = "*.epub", run = "epub" },
]

prepend_preloaders= [
  { name = "*.epub", run = "epub" },
]
```
