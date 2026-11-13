# Island

A macOS 14+ menu bar app with an animated black overlay around the camera notch.

## First milestone

- A transparent, nonactivating panel above the menu bar.
- Notch geometry from public AppKit screen APIs, with a pill fallback.
- Collapsed, compact, and expanded presentation states.
- Spring animation, hover, and click interaction.
- A modular interface for future features.
- Menu bar controls and shell settings.

Feature modules will follow after the core shell has been tested on hardware.

## Workspace Git history

This environment prevents writes to the workspace's `.git` path. Git metadata
is stored at `/private/tmp/island-workspace.git`; working files remain here.
Run Git commands from this directory with:

```sh
git --git-dir=/private/tmp/island-workspace.git --work-tree=. status
git --git-dir=/private/tmp/island-workspace.git --work-tree=. log --oneline
```

To preserve the repository in a conventional layout outside this restricted
workspace, clone the local history before the temporary directory is removed:

```sh
git clone /private/tmp/island-workspace.git ../Island-checkout
```
