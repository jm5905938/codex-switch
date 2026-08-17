# codex-switch

`codex-switch` 是一个仅供个人自用的 Zsh/Linux 工具。它自行实现按 Git
仓库划分的 `CODEX_HOME`，并让官方 ChatGPT 登录与第三方 Codex provider
共用该项目工作区；切换 provider 时可以保留项目记忆、session 历史和恢复
目标。

本项目与 OpenAI 无关联，也不替代 Codex 的官方配置文档。

> 原生 Codex 默认使用单一的 `~/.codex`。按仓库创建工作区是本工具提供的
> 自定义 shell 行为，不是 Codex 内置功能。

## 命令

| 命令 | Provider | 工作区 |
| --- | --- | --- |
| `cproj` | 原生 Codex 配置或手动传入的 profile | 当前项目的隔离工作区 |
| `cproj-api` | 第三方 Responses API | 当前项目的共享工作区 |
| `cproj-gpt` | 官方 OpenAI / ChatGPT | 当前项目的共享工作区 |
| `codex` | 第三方 Responses API | 当前项目的共享工作区 |
| `codex-gpt` | 官方 OpenAI / ChatGPT | 当前项目的共享工作区 |
| `codex-g` | 原生 Codex | 不修改全局 `CODEX_HOME` |

`cproj` 是项目级工作区隔离的基础入口。`codex` 与 `codex-gpt` 分别是
`cproj-api` 和 `cproj-gpt` 的快捷入口。它们针对当前 Git 仓库使用同一个
工作区。`codex-gpt resume` 会自动附加 `--all`，因此切换目录后仍能看到
通过两种 provider 创建的 session。

## 安装

```zsh
git clone https://github.com/OWNER/codex-switch.git
cd codex-switch
./install.zsh
source ~/.zshrc
```

安装器会向 `~/.zshrc` 添加一个带标记的 source 块，并把 shell 库复制到
`~/.config/codex-switch/codex-switch.zsh`。

## 首次配置

```zsh
codex-switch setup
codex-switch api-key
codex-gpt login
```

`setup` 会询问第三方 Responses API 的基础地址。`api-key` 将 key 保存到
`~/.config/codex-switch/api.env`，权限为 `0600`，新开的 Zsh shell 会自动
加载它。API key 不会写入 Codex 配置文件。

配置完成后：

```zsh
codex
codex-gpt
codex-gpt resume
```

## 工作区布局

本工具会为每个 Git 仓库自行创建一个目录：

```text
~/.codex-switch/workspaces/<仓库名>-<哈希>/
```

该目录保存 `auth.json`、session、记忆数据库和两个 provider profile。API
profile 使用 `CODEX_SWITCH_API_KEY`，GPT profile 使用共享工作区中的 ChatGPT
登录状态。API profile 不需要执行 `codex login`。

首次进入项目时，`cproj` 会将工作区的 `config.toml` 链接到原生
`~/.codex/config.toml`，因此 MCP、权限、模型等基础配置可以沿用；但认证、
session、记忆、缓存和日志会留在项目工作区内。这就是本工具将普通 Codex
部署为项目级隔离工作区模式的方式。

## 状态与卸载

```zsh
codex-switch status
./uninstall.zsh
```

卸载仅移除 `.zshrc` 中的 source 块，刻意保留配置、session 和记忆，避免
误删个人数据。

## 依赖

- Zsh
- Git
- 支持 `--profile` 的 Codex CLI
- 兼容 OpenAI Responses API 的第三方 endpoint

## 安全说明

- 本项目仅供个人自用。使用前请自行审查脚本，并理解第三方 provider 的
  数据处理与隐私政策。
- 不要提交 `api.env`、API key，或私有网关地址。
- 第三方 provider 会接收提示词、仓库上下文和已启用工具的输出；只使用你
  信任的 provider。
- 通过 `codex` 恢复 ChatGPT session 时，为了跨 provider 继续对话，Codex
  会将该 session 中可用的对话上下文发送给已配置的第三方 provider。不要
  通过不可信 provider 恢复敏感 session。
- `codex-g` 会绕过本工具，保留原生 Codex 行为。

## 开发

```zsh
zsh tests/smoke.zsh
```
