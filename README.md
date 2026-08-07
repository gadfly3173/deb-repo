# Debian APT Repository

Automatically maintained Debian package repository powered by GitHub Actions.

## Quick Setup

### Option 1: DEB822 format (recommended, Debian Bookworm / Ubuntu 22.04+)

```bash
# 1. Import GPG key
curl -fsSL https://deb-repo.gadfly.vip/public.key | sudo gpg --dearmor -o /usr/share/keyrings/deb-repo.gpg

# 2. Add repository source (.sources file)
sudo tee /etc/apt/sources.list.d/deb-repo.sources > /dev/null << EOF
Types: deb
URIs: https://deb-repo.gadfly.vip
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /usr/share/keyrings/deb-repo.gpg
EOF

# 3. Update and install
sudo apt update
```

> If no GPG key is configured, replace `Signed-By: ...` with `Trusted: yes`.

### Option 2: One-line format (compatible with all versions)

```bash
# 1. Import GPG key
curl -fsSL https://deb-repo.gadfly.vip/public.key | sudo gpg --dearmor -o /usr/share/keyrings/deb-repo.gpg

# 2. Add repository source (.list file)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/deb-repo.gpg] https://deb-repo.gadfly.vip stable main" \
  | sudo tee /etc/apt/sources.list.d/deb-repo.list

# 3. Update and install
sudo apt update
```

> If no GPG key is configured, use `[trusted=yes]` instead of `[signed-by=...]`.

## Supported Architectures

- **amd64** (x86_64)
- **arm64** (aarch64)

## Repository Info

| Field | Value |
|-------|-------|
| Suite | `stable` |
| Component | `main` |
| URL | https://deb-repo.gadfly.vip |

## Package Indexes

- [amd64 Packages](dists/stable/main/binary-amd64/Packages)
- [arm64 Packages](dists/stable/main/binary-arm64/Packages)

---

> This repository is automatically built and deployed via GitHub Actions.
> Source: [deb-repo](https://github.com/gadfly3173/deb-repo)
