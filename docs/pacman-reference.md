# CachyOS Package Management Reference

## Quick Commands

| Command | Purpose |
|---------|---------|
| `sudo pacman -Sy` | Refresh database only |
| `sudo pacman -Syu` | Refresh + upgrade system |
| `yay -Syu` | Refresh + upgrade system + AUR |
| `sudo cachyos-rate-mirrors` | Find fastest mirrors |
| `pacman -Qu` | List packages with updates |
| `yay -Qu` | List all packages with updates (including AUR) |

## CachyOS Repo Configuration

Your system uses these repos (in order of priority):

1. **cachyos-v4** - Optimized packages for x86-64-v4 CPUs (best performance)
2. **cachyos** - General CachyOS packages
3. **core/extra/multilib** - Standard Arch Linux repos

Config files:
- `/etc/pacman.conf` - Main pacman configuration
- `/etc/pacman.d/cachyos-mirrorlist` - CachyOS mirrors
- `/etc/pacman.d/cachyos-v4-mirrorlist` - CachyOS v4 mirrors
- `/etc/pacman.d/mirrorlist` - Arch Linux mirrors

## Mirror Refresh

```bash
# Update all mirrors (recommended)
sudo cachyos-rate-mirrors

# Manual mirror rating
sudo rate-mirrors --save /etc/pacman.d/cachyos-mirrorlist cachyos
sudo rate-mirrors --save /etc/pacman.d/mirrorlist arch
```

## Package Search

```bash
# Search official repos
pacman -Ss <package>

# Search including AUR
yay -Ss <package>

# Show package info
pacman -Si <package>

# List installed packages
pacman -Q

# List explicitly installed packages
pacman -Qe

# List orphaned packages (no longer needed)
pacman -Qdt
```

## Cleanup

```bash
# Remove orphaned packages
sudo pacman -Rns $(pacman -Qdtq)

# Clear package cache (keep last 3 versions)
sudo paccache -r

# Clear all cached packages
sudo pacman -Scc
```
