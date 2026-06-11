# Browser

This folder contains a browser homepage and a bookmarks import file.

## Homepage

Set this as the browser homepage:

```text
~/.config/browser/index.html
```

Firefox / Zen can use a local file URL:

```text
file:///home/woki/.config/browser/index.html
```

Homepage links are loaded from:

```text
~/.config/browser/links.json
```

The page also has an edit mode. Browser edit mode stores changes in localStorage.
To make edits permanent, copy the JSON back into `links.json`.

## Bookmarks

Import `bookmarks.html` in Firefox or Zen after reinstall.

1. Open bookmarks manager with `Ctrl+Shift+O`.
2. Select `Import and Backup`.
3. Select `Import Bookmarks from HTML...`.
4. Choose `~/.config/browser/bookmarks.html`.

The file is grouped by browser source and organization.
