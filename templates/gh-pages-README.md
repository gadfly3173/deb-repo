# Debian APT Repository

Automatically maintained Debian package repository powered by GitHub Actions.

## Quick Setup

```bash
# Import GPG key
curl -fsSL {{REPO_URL}}/public.key | sudo gpg --dearmor -o /usr/share/keyrings/{{REPO_NAME}}.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/{{REPO_NAME}}.gpg] {{REPO_URL}} stable main" \
  | sudo tee /etc/apt/sources.list.d/{{REPO_NAME}}.list

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
| URL | {{REPO_URL}} |

## Package Indexes

- [amd64 Packages](dists/stable/main/binary-amd64/Packages)
- [arm64 Packages](dists/stable/main/binary-arm64/Packages)

---

> This repository is automatically built and deployed via GitHub Actions.
> Source: [{{REPO_NAME}}]({{GITHUB_URL}})
