# Flow — Documentation

Flow is a CSS Flexbox-inspired UI library for [Defold](https://defold.com), written in pure Lua.

---

## Start Here

| Doc | Description |
|-----|-------------|
| [Getting Started](getting-started.md) | Install Flow, register GUI resources, and build your first screen |
| [Architecture](architecture.md) | How the three layers fit together |

---

## Tutorials

Step-by-step guides that build on each other.

| # | Tutorial | What you'll learn |
|---|----------|-------------------|
| 1 | [First Screen](tutorials/01-first-screen.md) | `flow.init`, `Box`, `Text`, GUI mounting, text fonts |
| 2 | [Layout & Style](tutorials/02-layout-and-style.md) | `flex_direction`, `justify_content`, `align_items`, `gap`, `padding`, `%` |
| 3 | [Navigation](tutorials/03-navigation.md) | Screens, `push`/`pop`, params, transitions |
| 4 | [Interactive UI](tutorials/04-interactive-ui.md) | `Button`, `ButtonImage`, rounded backgrounds, hover, state mutation |
| 5 | [Scroll & Lists](tutorials/05-scroll-and-lists.md) | Scroll containers, virtual scrolling for large lists |
| 6 | [Overlays](tutorials/06-overlays.md) | Popup, bottom sheet, animated slide-in |

---

## Guides

Deep-dives on specific topics.

| Guide | Description |
|-------|-------------|
| [Best Practices](guides/best-practices.md) | Keys, heights, node budget, invalidation and redraw patterns |
| [Debugging](guides/debugging.md) | Debug mode, log levels, per-context logging |

---

## API Reference

Module-level contracts in [`specs/`](../specs/README.md).

| Spec | Module |
|------|--------|
| [layout.md](../specs/layout.md) | `flow/layout.lua` — pure flex layout engine |
| [ui.md](../specs/ui.md) | `flow/ui.lua` — renderer, input, animation |
| [navigation.md](../specs/navigation.md) | `flow/navigation` — stack-based navigation |
| [flex.md](../specs/flex.md) | `flow/flex.lua` — Yoga-compatible imperative API |
| [markdown.md](../specs/markdown.md) | `flow/components/markdown.lua` — markdown viewer |
| [log.md](../specs/log.md) | `flow/log.lua` — leveled logging |
