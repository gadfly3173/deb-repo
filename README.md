# Debian APT Repository

Automatically maintained Debian package repository powered by GitHub Actions.

## Quick Setup

```bash
# Import GPG key
curl -fsSL https://gadfly3173.github.io/deb-repo/public.key | sudo gpg --dearmor -o /usr/share/keyrings/deb-repo.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/deb-repo.gpg] https://gadfly3173.github.io/deb-repo stable main" \
  | sudo tee /etc/apt/sources.list.d/deb-repo.list

# Update and install
sudo apt update
```

## Supported Architectures

- **amd64** (x86_64)
- **arm64** (aarch64)

## Repository Info

| Field | Value |
|-------|-------|
| Suite | `stable` |
| Component | `main` |
| URL | https://gadfly3173.github.io/deb-repo |

## Package Indexes

- [amd64 Packages](dists/stable/main/binary-amd64/Packages)
- [arm64 Packages](dists/stable/main/binary-arm64/Packages)

---

> This repository is automatically built and deployed via GitHub Actions.
> Source: [deb-repo](https://github.com/gadfly3173/deb-repo)
