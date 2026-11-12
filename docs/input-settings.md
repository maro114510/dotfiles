# Input settings

Input-related settings have different owners. Keep each setting in the
application that consumes it, and use `chezmoi apply` for files owned by this
repository.

| Setting | Source of truth | Apply or restore |
| --- | --- | --- |
| Keyboard and pointing-device remaps | `dot_config/private_karabiner/private_karabiner.json` | `chezmoi apply`; Karabiner Elements reads `~/.config/karabiner/karabiner.json` |
| macOS keyboard, mouse, and Finder preferences | `run_once_after_setup-macos-defaults.sh` | `chezmoi apply` runs the script once per content version |
| Raycast preferences and extensions | `dot_config/raycast/*.rayconfig` and `dot_raycast/` | Import the `.rayconfig` in Raycast; `chezmoi apply` installs the managed extension files |

## Ownership rules

- Edit Karabiner mappings in the JSON source, not in the generated file under
  the home directory.
- Edit macOS preference values in the setup script. These are imperative
  settings, so changing them requires changing the script content and running
  `chezmoi apply` again.
- Treat Raycast exports as backups/import sources. Raycast remains the owner of
  runtime state; do not commit its caches, secrets, or database files.
- Vial layouts are not managed here. Track them in a new Issue once a verified
  `.vil` export exists.

## Applying changes

```bash
chezmoi diff
chezmoi apply
```

After applying, import a changed Raycast export from Raycast's import flow.
Verify the resulting settings in each application's UI; `chezmoi diff` only
verifies files managed by chezmoi.
