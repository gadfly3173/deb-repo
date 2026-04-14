# Debian APT Repository

Automatically maintained Debian package repository powered by GitHub Actions.

## Quick Setup

### Option 1: DEB822 format (recommended, Debian Bookworm / Ubuntu 22.04+)

```bash
# 1. Import GPG key
curl -fsSL {{REPO_URL}}/public.key | sudo gpg --dearmor -o /usr/share/keyrings/{{REPO_NAME}}.gpg

# 2. Add repository source (.sources file)
sudo tee /etc/apt/sources.list.d/{{REPO_NAME}}.sources > /dev/null << EOF
Types: deb
URIs: {{REPO_URL}}
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /usr/share/keyrings/{{REPO_NAME}}.gpg
EOF

# 3. Update and install
sudo apt update
```

> If no GPG key is configured, replace `Signed-By: ...` with `Trusted: yes`.

### Option 2: One-line format (compatible with all versions)

```bash
# 1. Import GPG key
curl -fsSL {{REPO_URL}}/public.key | sudo gpg --dearmor -o /usr/share/keyrings/{{REPO_NAME}}.gpg

# 2. Add repository source (.list file)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/{{REPO_NAME}}.gpg] {{REPO_URL}} stable main" \
  | sudo tee /etc/apt/sources.list.d/{{REPO_NAME}}.list

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
| URL | {{REPO_URL}} |

## Package Indexes

- [amd64 Packages](dists/stable/main/binary-amd64/Packages)
- [arm64 Packages](dists/stable/main/binary-arm64/Packages)

---

> This repository is automatically built and deployed via GitHub Actions.
> Source: [{{REPO_NAME}}]({{GITHUB_URL}})
