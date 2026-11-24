# SandFly Scripting Skill

**一句话**：把“为 SandFly 读屏软件编写脚本和宏”的完整能力打包成一个 AI 技能——装进支持技能的 AI 工具后，你用自然语言描述功能，AI 就能产出可直接安装的脚本或宏。

一个 [Agent Skill](https://agentskills.io) 格式的技能包，适配 SandFly 0.7.0 / 脚本 API v6。你只需描述想法（必要时提供应用的控件信息），AI 就会按正确流程产出交付物。

## 这是什么

[SandFly](https://github.com/aaron-gh/SandFly) 是 Android 读屏软件（Google TalkBack 的分支），支持用 Lua 脚本定制任意应用的读屏体验，也支持在设置里搭建自动化宏和新版的脚本生成器。但脚本 API 有上百个调用、不少限制和陷阱，手写门槛不低。

这个技能把官方文档、编写流程和示例打包成标准 Agent Skills 格式，让 AI 按正确的方式代写：先访谈需求、确认方案，再写代码；失败时先看日志定位原因，而不是盲目重写。

## AI 能帮你写什么

- **改造某个应用**：控件改名、隐藏广告、把一整行合并为一个朗读项、调整朗读顺序
- **加命令**：手势一键跳到未读消息、按键触发搜索、菜单里加自己的功能
- **自动响应**：进入应用报出状态、拦截并改写 SandFly 要说的话、监听通知
- **自动化流程**（宏）：打开应用 → 等待 → 按文本找到按钮 → 点击，一条手势搞定
- **免代码配置**：用 SandFly 的脚本生成器配置规则、阅读控制、触发器和朗读改动
- **更复杂的**：调网络 API 查词、记事本小应用、屏幕 OCR 识别文字

## 仓库结构

本仓库是一个单技能仓库。技能本体放在标准的 `skills/<技能名>/` 目录下，方便被各种工具从 GitHub 直接发现和导入。

```text
sandfly-scripting-skill/            # 本仓库根目录
├── skills/
│   └── sandfly-scripting/          # 安装、导入时使用的技能目录
│       ├── SKILL.md                # 技能主文件：六步工作流、选型、权限表、API 速查、陷阱清单
│       ├── references/
│       │   ├── api.md              # 官方脚本 API 文档完整副本（docs/scripting.md，API v6）
│       │   ├── item-files.md       # 宏/条目文件 JSON 格式（含 do 步骤补充）
│       │   └── macros.md           # 用户指南宏章节：步骤、条件、录制与运行
│       └── examples/
│           ├── example-plugin.lua  # 官方入门示例
│           ├── app-tweaks.lua      # 单应用定制综合示例
│           ├── wikipedia-search.lua# 官方 onDemand + 网络示例（v6 修正版）
│           ├── notepad.lua         # 官方窗口小应用示例
│           └── talking-clock.lua   # 官方熄屏运行 + 定时器示例
├── README.md                       # 本文件
├── LICENSE                         # Apache License 2.0
├── NOTICE                          # 上游 SandFly 来源说明
└── .gitignore
```

仓库已按这个结构发布，导入时工具会自动定位到 `skills/sandfly-scripting/`。

生成的 `sandfly-scripting.zip` 不放在源码仓库里，作为 GitHub Release 附件发布。

## 从 GitHub 导入

很多支持 Agent Skills 的工具可以直接从 GitHub 拉取本仓库：

```bash
# 通用 skills CLI：发现仓库中的技能并安装到已检测的 AI 工具
npx skills add LiJin0312/sandfly-scripting-skill

# 只安装这一个技能
npx skills add LiJin0312/sandfly-scripting-skill --skill sandfly-scripting -y

# 也可以直接指向技能目录
npx skills add https://github.com/LiJin0312/sandfly-scripting-skill/tree/main/skills/sandfly-scripting
```

GitHub Copilot CLI 用户（需要 GitHub CLI 2.90+）：

```bash
gh skill preview LiJin0312/sandfly-scripting-skill sandfly-scripting
gh skill install LiJin0312/sandfly-scripting-skill sandfly-scripting
```

如果工具没有命令行导入，就手动下载/克隆仓库，把 `skills/sandfly-scripting/` 这个**子目录**复制到工具的 skills 目录（不要复制仓库根目录）。

## 手动安装

| 工具 | 用户级（所有项目可用） | 项目级 |
|---|---|---|
| **WorkBuddy** | `~/.workbuddy/skills/sandfly-scripting/` | `<repo>/.workbuddy/skills/sandfly-scripting/` |
| **ZCode** | `~/.zcode/skills/sandfly-scripting/` | `<repo>/.zcode/skills/sandfly-scripting/` |
| **Claude Code** | `~/.claude/skills/sandfly-scripting/` | `<repo>/.claude/skills/sandfly-scripting/` |
| **GitHub Copilot** | `~/.copilot/skills/sandfly-scripting/` | `<repo>/.github/skills/sandfly-scripting/` |
| **其他支持 Agent Skills 的工具** | 参照该工具文档的 skills 目录 | 同左 |

Windows 下 `~` 即 `C:\Users\<用户名>`。复制时保持目录名为 `sandfly-scripting`，且 `references/`、`examples/` 要和 `SKILL.md` 在同一级。重启会话（或新开会话）后生效；描述需求时提到 SandFly / 读屏脚本即会触发，也可以直接输入 `/sandfly-scripting` 显式调用（取决于工具是否支持斜杠调用技能）。

## 使用

装好后用大白话对 AI 说想法即可，**不懂编程也没关系**——AI 全程用大白话提问（大多是选择题），包名、控件信息这些技术细节它会教你怎么提供，你只需要描述想法并按它说的操作手机。例如：

> 帮我写个 SandFly 脚本：在邮件应用里把归档那个按钮改名叫“归档”，再加一个手势一键跳到下一封未读。

AI 会**先问清需求**（希望什么时候干活、在哪个应用、想听到什么），复述并和你确认方案后才写代码；需要控件信息时，会让你在 SandFly 里运行“复制屏幕树”手势，把发来的内容整个粘贴给它。产出文件后，按它给的步骤在手机上 **设置 → 脚本 → 导入脚本** 安装并测试。如果不符合预期，把脚本页面的 **日志** 内容原样发给 AI（看不懂没关系），它会先定位原因再修改，而不是盲目重写。简单的固定流程 AI 会直接给宏 JSON，在 **设置 → 宏** 导入，无需写代码。

## 要求

- 手机/平板上的 SandFly 0.7.0 或更新版本（脚本 API v6；手表和电视不支持脚本）
- 想用按键注入类功能（`sf.keys.*`）需安装 [Shizuku](https://shizuku.rikka.app)

## 维护与更新

SandFly 的脚本 API 随版本演进（本包同步于 2026-11-24，对应 SandFly 0.7.0 / API v6）。仓库更新后，在 `skills/sandfly-scripting/` 下重新复制：

- `docs/scripting.md` → `references/api.md`
- `docs/reference/item-files.md` → `references/item-files.md`
- `docs/user-guide/en/16-macros.md` → `references/macros.md`
- `docs/scripting/examples/*.lua` → `examples/`

然后按新版本修正 `SKILL.md` 中的版本号、权限与限制。改完可用技能校验工具检查 `skills/sandfly-scripting/` 目录。

## 来源与许可

内容整理自 [SandFly](https://github.com/aaron-gh/SandFly) 仓库的官方文档与示例，遵循 Apache License 2.0。详见仓库内的 `LICENSE` 与 `NOTICE`。
