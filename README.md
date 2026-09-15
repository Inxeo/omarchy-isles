# Isles

Breathing islands behind the stock [Omarchy](https://omarchy.org/) bar. The bar stays Omarchy’s; Isles only paints chrome underneath the widgets.

One chip on the bar opens the panel: looks (cluster, pills, rail, powerline, brackets, glow), stroke style and width, fill vs stroke opacity, padding, and radius.

## A nod to Rice Bar

Isles exists because [Rice Bar](https://github.com/jcarcinogen/omarchy-rice-bar) showed that the stock bar could look designed without replacing it. Same rule, same appetite: **own the chrome, not the widgets.**

Rice Bar did that by talking to the live bar object — slot geometry, transparency, icon colours. That was the right call on Omarchy 4.0.1.

On **4.0.3** the shell stopped injecting that object into third-party widgets. Third-party code gets a postcard (size, edge, colours) and must not mutate the host. Rice Bar’s overlay still maps; it can no longer measure widgets or restyle the bar, so the islands go blank.

Isles works on 4.0.3 by staying inside the rules that are left:

- A bar-widget already sits in the shared QML scene. It walks neighbouring slots for size and visibility (the postcard does not include that tape measure).
- Chrome is drawn **in the bar window, under the widgets**, not as a second layer-shell surface stacked on top.
- Settings are this plugin’s own keys, saved with `omarchy bar set` — the same public CLI the rest of the shell uses.

No fork of `omarchy.bar`. No writing `bar.transparent` or `bar.foreground`.

## Edges

**Top and bottom** are the happy path. Transparent bar, islands behind the icons, theme-light glyphs.

**Left and right** lay out correctly (islands follow the strip, pills and powerline stack). What goes wrong is **Omarchy**, not Isles: a transparent bar runs `omarchy-bar-text-color`, which samples the **wallpaper along that edge** and picks light or dark text for contrast. A bright side of a photo makes icons almost black, so they look missing on the islands. Double-click the bar to make it solid and the theme’s light text comes back. Isles cannot override that colour — 4.0.3 does not let a third-party widget set `bar.foreground`.

So: use it on the top (or bottom) edge. Side bars work as chrome; the glyphs may not.

## Install

This repository is **private**. Clone only works if you have access (your GitHub account, or a collaborator invite).

```bash
omarchy plugin add https://github.com/Inxeo/omarchy-isles.git --enable
```

If HTTPS cannot see a private repo, use SSH (and a GitHub account that has been invited):

```bash
omarchy plugin add git@github.com:Inxeo/omarchy-isles.git --enable
```

Put the chip where you want it (often the right cluster):

```bash
omarchy bar move io.github.inxeo.isles --section right
```

The bar should be transparent (`omarchy bar transparent true`, or double-click empty bar) so the islands show through.

Requires Omarchy 4.0.3+ (Quattro shell plugins).

## Looks

| Look | What it paints |
|---|---|
| Cluster | One island per bar section (left / center / right) |
| Pills | One island per icon |
| Rail | One strip the full length of the bar |
| Power | Chevron segments per icon, grouped by section |
| Brackets | Corner ticks (optional fill) |
| Glow | Cluster islands with a soft bloom |

Stroke (All, Top, Bottom, T+B, Sides, Ends) applies to Cluster, Pills, Rail, and Glow. Width `0` is no stroke. Fill and stroke have separate opacity sliders.

## Remove

```bash
omarchy plugin remove io.github.inxeo.isles --yes
```

Stock widgets are untouched.

## Contributors

- **Inxeo** — design, taste, and the brief
- **Grok** ([Grok Build](https://x.ai/)) — implementation

## License

MIT. Rice Bar remains the original chrome idea; this is a 4.0.3-era way to get a slice of that look.
