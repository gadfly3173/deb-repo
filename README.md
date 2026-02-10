# Debian APT Repository

通过 GitHub Actions 自动构建和维护的 Debian APT 仓库。支持从推送的 .deb 包和上游 GitHub Release 自动同步。

## 分支说明

| 分支 | 用途 |
|------|------|
| `master` | 项目代码、配置文件、.deb 包存放。推送后自动触发仓库构建 |
| `gh-pages` | 生成的 Debian 仓库静态文件（自动维护，勿手动修改） |

## 工作流程

### 1. 手动推送 .deb 包

将 .deb 文件放到仓库根目录并推送到 `master`，GitHub Actions 会自动：

1. 收集根目录所有 `.deb` 文件
2. 复制到 `pool/main/` 目录
3. 按架构（amd64/arm64）生成 `Packages` 索引
4. 生成 `Release` 文件并 GPG 签名
5. 部署到 `gh-pages` 分支

```bash
# 添加 .deb 包到仓库根目录
cp /path/to/package_1.0_amd64.deb .
git add *.deb
git commit -m "feat: add package_1.0_amd64.deb"
git push origin master
```

### 2. 自动同步上游 Release

GitHub Actions 每日 06:00 UTC 自动执行，也可在 Actions 页面手动触发。

流程：
1. 读取 `upstream-repos.json` 中配置的仓库列表
2. 查询每个仓库的最新 Release
3. 下载所有 `.deb` 文件（跳过已存在的）
4. 自动识别架构（amd64/arm64/x86_64/aarch64/all）
5. 重建仓库并部署

## 配置

### upstream-repos.json

在仓库根目录编辑此文件，定义需要同步的上游仓库：

```json
[
  {
    "owner": "sourcegit-scm",
    "repo": "sourcegit",
    "pattern": "*.deb"
  }
]
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `owner` | 是 | GitHub 用户名或组织名 |
| `repo` | 是 | 仓库名 |
| `pattern` | 否 | 文件匹配模式，默认 `*.deb` |

### GitHub Secrets

在仓库 Settings > Secrets and variables > Actions 中配置：

| Secret | 必填 | 说明 |
|--------|------|------|
| `GPG_PRIVATE_KEY` | 否 | GPG 私钥（ASCII-armored 格式），用于仓库签名 |
| `GPG_PASSPHRASE` | 否 | GPG 密钥口令（如果私钥有口令保护） |

#### 生成 GPG 密钥

```bash
# 生成密钥
gpg --full-generate-key
# 选择: (1) RSA and RSA, 4096 bits, 不过期

# 查看密钥 ID
gpg --list-secret-keys --keyid-format long
# 输出类似: sec   rsa4096/ABCDEF1234567890

# 导出私钥（粘贴到 GPG_PRIVATE_KEY secret）
gpg --export-secret-keys --armor ABCDEF1234567890
```

> 如果不配置 GPG 密钥，仓库仍可正常工作，但用户需要在 APT 源配置中添加 `[trusted=yes]`。

### GitHub Pages

1. 进入仓库 Settings > Pages
2. Source 选择 **Deploy from a branch**
3. Branch 选择 `gh-pages`，目录选 `/ (root)`
4. 保存

仓库地址将为：`https://<username>.github.io/<repo-name>`

## 仓库结构（gh-pages 分支）

```
├── index.html              # 使用说明页面
├── README.md               # 仓库说明
├── public.key              # GPG 公钥（如有配置）
├── dists/
│   └── stable/
│       ├── Release          # 仓库元数据
│       ├── InRelease        # 签名的元数据
│       ├── Release.gpg      # 分离签名
│       └── main/
│           ├── binary-amd64/
│           │   ├── Packages
│           │   └── Packages.gz
│           └── binary-arm64/
│               ├── Packages
│               └── Packages.gz
└── pool/
    └── main/
        ├── package1_1.0_amd64.deb
        └── ...
```

## 用户端配置

部署完成后，终端用户按以下步骤添加仓库：

```bash
# 1. 导入 GPG 公钥
curl -fsSL https://<username>.github.io/<repo>/public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/deb-repo.gpg

# 2. 添加仓库源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/deb-repo.gpg] \
  https://<username>.github.io/<repo> stable main" \
  | sudo tee /etc/apt/sources.list.d/deb-repo.list

# 3. 更新并安装
sudo apt update
```

## 支持的架构

- `amd64` (x86_64)
- `arm64` (aarch64)
- `all` (架构无关包，同时包含在两个架构索引中)

## 文件说明

```
├── .github/workflows/
│   ├── build-on-push.yml    # Push 触发的仓库构建 workflow
│   └── sync-upstream.yml    # 上游同步 workflow
├── scripts/
│   ├── build-repo.sh        # 仓库构建脚本
│   ├── generate-pages.sh    # gh-pages 页面生成（从模板替换变量）
│   └── sync-upstream.sh     # 上游包同步脚本
├── templates/
│   ├── gh-pages-index.html  # gh-pages index.html 模板
│   └── gh-pages-README.md   # gh-pages README.md 模板
├── upstream-repos.json      # 上游仓库配置
├── *.deb                    # 手动添加的 .deb 包
├── .gitignore
└── README.md
```
