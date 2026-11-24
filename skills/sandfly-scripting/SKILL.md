---
name: sandfly-scripting
description: 为 SandFly（Android 读屏软件，TalkBack 的分支，脚本 API v6）编写 Lua 脚本、脚本生成器配置或宏，定制任意应用的读屏体验：修改朗读、改名或隐藏控件、添加手势命令、自动化点击流程、响应通知与焦点事件、控制系统与设备。当用户想为 SandFly 或 TalkBack 定制功能、写读屏脚本/插件/宏时使用。
license: Apache-2.0
agent_created: true
---

# SandFly 脚本与宏编写

为 SandFly（Android 读屏软件，Google TalkBack 的分支，当前版本 0.7.0）编写宏、脚本生成器配置或 Lua 脚本。用户描述功能后，**先访谈需求到信息齐全、经用户确认方案后才写代码**；失败时先取证（日志、屏幕树）再修复，不盲目重写。交付物是可直接安装的宏 JSON、脚本生成器配置说明，或 `.lua` / `.zip` 脚本文件。**假定用户不懂编程**：所有提问、方案说明和调试解释都说大白话（见下面的沟通原则），技术细节全部由你承担——只要有想法，普通用户就能用这个流程做出自己的插件。

代码注释用用户的语言（通常是中文），API 名称、manifest 字段保持英文原样。无法在本机运行 SandFly 来测试脚本——用户的手机是唯一的运行环境，所以每次交付都相当于一次"带测试计划的发布"。

## 背景知识（先读这个）

SandFly 支持三种用户定制，按复杂度从低到高：

1. **宏**：在 设置 → 宏 里可视化编辑的步骤列表，无需代码。每个宏成为一个命令，可分配给手势、按键、菜单、语音命令或桌面快捷方式。固定流程优先选宏；能力包括运行命令、等待、按文本/类型找项目并点击/长按/滚动/聚焦/朗读、按坐标点击、触摸保持、输入文本、打开应用、条件、循环、更多设备步骤（声音、剪贴板、链接、设置页、音量、设备控件、媒体键、定时器、闹钟、电话、短信、相机、按键、值）。格式见 `references/item-files.md`，界面说明见 `references/macros.md`。
2. **脚本生成器**：设置 → 脚本 → 新建脚本，用界面配置规则、阅读控制、命令步骤、触发器、朗读改动、设置，并可附加 Lua 代码。主要是改朗读/隐藏/改名/排序/分组、读控制或固定触发步骤时，优先建议用户用它；复杂的动态逻辑才需要手写 Lua。生成器导出的仍然是普通 `.zip` 脚本。
3. **Lua 脚本**：Lua 5.4 写的 `.lua` 文件（≤1 MB）或含 `main.lua` 的 `.zip`（≤5 MB、解压后 ≤5 MB、≤200 个文件），通过 `sf` 表访问完整 API。**当前脚本 API 版本 6**（SandFly 0.7.0）。仅在手机/平板上运行，手表、电视不支持。

运行环境要点：有 `string/table/math/utf8/coroutine`、`os.time/clock/date/difftime`、`json`；**没有** `io/debug/package/dofile/loadfile`，不能用 `os.execute`，不能读写手机文件（只能读脚本包内的文件）；Android 调用只能经 `sf`，或申请 `java` 权限。每次调用脚本最多 2 秒，语音钩子共享 30 毫秒，`onActions` 50 毫秒，内存 32 MB。脚本在 SandFly 自己的设置界面上不生效；熄屏、暂停 SandFly、"关闭所有脚本"时脚本被卸载（除非用户开启"保持熄屏运行"）。

## 工作流程（六个阶段，按顺序走）

纪律只有四条：**信息没齐不动手；方案没确认不写码；失败先取证再修复；提问永远说大白话。** 用户明确说"直接写，不用问"时可跳过阶段 1 的提问，但仍要在回复开头列出你所做的全部假设。

**沟通原则（贯穿所有阶段——假定用户不懂编程）：**

- **说人话，不甩术语。** 必须用术语时跟一句白话解释。不说"需要 view id"，说"我需要那个按钮在系统里的内部名字——你在那个界面上运行一次'复制屏幕树'，把手机发来的内容整个粘贴给我，我自己从中找"。
- **能出选择题就不出填空题。** "你想要哪种：A. 做个手势它才执行；B. 一打开应用就自动执行；C. 两种都要"比让用户描述"触发方式"容易得多。
- **每个问题带一个例子。** 用用户手机上大概率有的应用举例（"比如微信里？"）。
- **指路具体到点哪里。** 不说"查看日志"，说"打开 SandFly 设置 → 脚本 → 点这个脚本的名字 → 里面的'日志'，点'复制日志'发给我。看不懂没关系，原样发来就行"。
- **技术活全部自己扛。** 包名、id、权限、版本号、API 选择都不要求用户提供——用户只负责描述想法和操作手机。
- **报错原文可以贴，但必须配一句白话解释。** "报错说脚本没拿到'通知'权限——意思是我当时忘了声明要读通知，加上就好。"

### 阶段 1：需求访谈

用户一句"帮我写个某某脚本"通常不够。先对照"够写标准"自查——**缺任何一项就先问，禁止开始写代码**：

| # | 必须知道 | 缺了会怎样 |
|---|---|---|
| 1 | 触发方式：手动（哪个手势/按键/菜单项/朗读控制）还是自动（哪个事件：进入应用、焦点变化、通知、文本变化、点击、定时…） | 没法定 API 形态（命令、宏还是钩子） |
| 2 | 作用范围：哪个应用的包名（只有全局脚本/全局宏可省略） | 作用范围靠猜，大概率不生效 |
| 3 | 期望行为：具体到"听到什么、点什么、什么顺序、什么条件" | 写出的行为与预期偏差 |
| 4 | （要定位控件时）真实的控件信息：view id / 按钮文本 / 屏幕树 / 聚焦项详情 | 臆造 id 必然失败 |
| 5 | （用到 v2–v6 的 API 或 v6 宏步骤时）用户的 SandFly 是否够新 | 旧版上调用直接报错 |

问的方式：

- 一次最多问 3–4 个问题，每个写明"答案会改变什么"；用户答不上来的给默认选项让其挑选，不要让用户自由发挥技术细节。
- 用户说"你决定/随便"时：列出你的默认假设再继续，并在交付时注明这些假设。
- 先看再问：工作区里有 SandFly 仓库时先查文档，用户消息里已给出的信息不要重复问。
- 信息已经齐全时不必再问，直接复述进入阶段 2。

**每项标准的"人话问法"参考**（按用户能答的方式问，不要照念标准表）：

| 要弄清什么 | 可以这样问 |
|---|---|
| 触发方式 | "你希望它什么时候干活？A. 你做个手势它才做；B. 一打开某个应用它就自动做；C. 有新通知它就做" |
| 作用范围 | "这个功能要在哪个应用里用？方便的话在那个应用里打开'复制屏幕树'发给我，我就能确认" |
| 期望行为 | "做完之后你想听到什么？比如念出内容、报个名字，还是悄悄做完就行？" |
| 找不到目标时 | "如果那一屏没有你要找的东西，你希望它说一声'没找到'，还是做点别的？" |
| 控件信息 | "在那个界面上运行一次'复制屏幕树'手势，把手机发来的内容整个粘贴给我，我自己从里面找那个按钮" |

**控件信息怎么拿**（对应标准第 4 项，按可靠性排序，命令都在 设置 → 命令 → 开发者设置，可分配到手势或加进菜单）：

1. **检查聚焦项目（Inspect focused item）**：打开 **项目详情** 窗口，含文本、项目类型、**内部项目**（按朗读顺序列出层级、类名、可点击、文本）等；详情可双击复制某一项，也有 **复制全部**。想知道按钮和同文字标题的区别时最有用。
2. **复制项目详情（Copy item details）**：把同一份详情复制为文本。
3. **复制屏幕树（Copy screen tree）**：复制当前窗口每个项目的文本行，开头是应用、活动、窗口标题；每行依次是层级、类名、id、角色、状态、文本、命名动作和适用的脚本规则。层级为 0 的是窗口顶层项目，子项属于上方最近的更低层级项目。**它现在是文本行，不是 JSON**。
4. 都不方便时：直接问控件上显示的文字，用 `textContains` / `contains` / `contentDescription` 匹配；包名可在系统设置 → 应用里查，或 `adb shell pm list packages`。

**绝不编造 view id 或类名**。没有把握就用文本匹配并注明"之后可用屏幕树校准"，或请用户补发屏幕树。id 可用短形式（`send_button`）或完整形式（`com.example:id/send_button`），代码里可用 `item.id and item.id:match('name$')` 两种通吃。

### 阶段 2：方案确认

信息齐全后，用三四行**复述需求**（做什么、何时触发、在哪生效、找不到目标时的行为），附上一个用大白话写的 3–6 行小方案，请用户确认后再写代码。方案说行为和影响，不说代码概念：

- **它会长什么样**：在宏、脚本生成器、Lua 脚本中选最简的一种。
  - **选宏**：手动触发 → 依次执行固定步骤（运行命令、等待、点击/长按/滚动/聚焦/朗读项目、按坐标点击、输入文本、打开应用、更多设备步骤，支持 如果/否则如果/否则、重复/重复直到、等待直到）。产出条目文件 JSON（格式见 `references/item-files.md`、步骤名见 `references/macros.md`），用户在 设置 → 宏 → 从文件导入，再到 设置 → 命令 → 宏 分配手势；`"actions": true` 可让它出现在项目的 Actions 菜单。之后跳到阶段 4。
  - **选脚本生成器**：主要是规则改名/隐藏/分组/朗读顺序/动作、阅读控制、定时或事件触发、朗读文字改动、简单设置。告诉用户去 设置 → 脚本 → 新建脚本，逐项给出应填的内容；需要自定义逻辑时在 代码 → Lua 代码 里补一小段。
  - **选 Lua 脚本**：需要动态逻辑、复杂钩子、网络请求、zip 内多文件或精细控制。
  - 拿不准时给用户说清取舍并让其挑；默认选最简单的能完成需求的那种。
- **什么时候生效**：在哪个应用里、做了什么操作之后。
- **需要什么、为什么**：权限用白话讲——"它需要联网，因为要去查那个网站"；"它会读你的通知，因为它要帮你过滤消息"。
- **主要过程**：一两句。
- **做不到的要直说**：比如"那个按钮如果不在当前屏幕上，它帮不了，到时你需要把那个界面发给我"。

小而明确的需求，可以把复述、方案和确认请求合并在一条消息里；用户同意（或说"直接写"）才进入阶段 3。

### 阶段 3：编写

**manifest 模板**（`main.lua` 开头；必须是 `local manifest = {...}`，只含字面值）：

```lua
local manifest = {
  id = 'my-script',          -- 必填：小写字母/数字/点/横线/下划线，字母或数字开头，≤64 字符
  name = 'My Script',        -- 必填：显示名，也是所有对话框标题的前缀
  author = 'Your Name',      -- 必填
  minApiVersion = 1,         -- 必填：脚本用到的 API 中最高的 *Version N* 标记
  testedApiVersion = 6,      -- 必填：实际测试过的最高版本（当前 SandFly 0.7.0 是 6）
  version = '1.0',           -- 改动后必须递增（自动更新按它比较，'1.10' 比 '1.9' 新）
  description = '一句话说明',
  homepage = 'https://example.com',  -- 可选：脚本页面出现 Open homepage
  apps = 'com.example.app',  -- 省略 = 全局脚本；也可用列表或 {package=, activity=, window=} 限定
  permissions = { 'screen', 'speech', 'input' },  -- 最小够用
  -- 按需再加：rules / commands / navigation / settings / onDemand / keepLoaded
}
```

manifest 规则：

- 表要么是纯列表（`{'a','b'}`）要么是纯记录（`{id='x'}`），不能混；空表 `{}` 算空列表。
- **不能有**变量、函数调用、`..` 拼接；注释可以。
- `minApiVersion` 不是随手填 1：`references/api.md` 里每个 API 都标了 *Version N*，用到哪个最高版本就填几。v2–v6 对 v1 只是添加，不改旧调用。
- `commands` 每项有 `id`、`title`，还可带 `gesture`、`keys`、`menu = true`、`control = true`。**v6 起：只有 `id`/`title` 的命令不需要 `input` 权限**；一旦带 `gesture`/`keys`/`menu`/`control` 就需要 `input`。`navigation` 和规则里的动作也需要 `input`。
- 未知字段：顶层字段 SandFly 忽略，但规则、查询、动作、导航里的未知字段会导致导入失败并指出字段名。

**代码要点**：

- **能等待的调用**：对话框、`sf.fetch`、`sf.sleep`、item 的动作方法、触摸/按键、`sf.commands.run`、`sf.macros.run`、`sf.screen.waitFor`、文字识别、`sf.translate`、`sf.speech.last()`、`sf.device.set`、`sf.system.openApp` 与系统动作、`sf.playSound`、`sf.speak(..., {wait=true})`。
- **能等待的场景**：主文件、命令回调、除四个语音钩子外的钩子、`onActions` 返回的各个 `run` 函数、定时器回调、对话框回调、`sf.run(function() ... end)`、脚本自己的协程。等待时不占用 2 秒时限，但每次等待之间的代码仍有 2 秒。
- **不能等待的场景**：4 个语音钩子 `onFocus` / `onSpeech` / `onNotification` / `onAnnouncement`——共享 30 毫秒，超时就直接朗读；`onActions` 本身必须在 50 毫秒内返回，慢事放进它返回的 `run` 函数或 `sf.run(...)`。
- **item 是快照**：字段不随屏幕变化；屏幕变了调 `item:refresh()` 取新的。超过最近 500 个的旧 item 用了会报错。
- **带 `apps` 的脚本**在应用切走时卸载，局部变量丢失 → 需要保留的状态放 `sf.storage`。`onAppLeave` 只有 250 毫秒。
- **版本兼容**：脚本可用 `sf.apiVersion` 判断运行环境并降级；v6 新增调用要提示用户升级 SandFly。
- 静态改动优先用 manifest 的 `rules`（不改代码就能改名/隐藏/合并/排序/加动作）；动态逻辑才用钩子。v6 规则可用 `read` 安排朗读片段、`buttonActions` 把内部按钮变成 Actions 项、`steps` 做连续动作。
- 用 `sf.text.replace/find/edit` 处理文本（v6，无需权限）；生成器里的"朗读改动"对应 `sf.text.edit`。
- 在不确定成败的关键路径上加 `print()` / `sf.log.warn(...)` 打点（阶段 5 要靠 Log 定位）；`print` 输出表格会写成 JSON。

**交付前自查清单**：

- [ ] manifest 全是字面值；id 格式合法；必填字段齐全；`version` 已递增
- [ ] `minApiVersion` 与用到的最高 *Version N* 一致；`testedApiVersion` = 6 或实测版本
- [ ] 逐个检查每个 `sf.*` 调用所需权限都在 `permissions` 里（对照下方权限表）；v6 下无分配的命令不必加 `input`
- [ ] `sf.onCommand` 的每个 id 都已在 manifest 的 `commands` 里声明（否则脚本报错）
- [ ] 语音钩子内没有等待调用；`onActions` 本身不等待，`run` 里才做慢事
- [ ] 查询里的 id / text / className 来自用户提供的真实信息，没有臆造
- [ ] 手势名是 `references/api.md` Gestures 一节里的精确拼写（含新增的多段滑动、轻点后滑动等名称）
- [ ] 数字限制：manifest 规则 ≤500（其中 `match` ≤100）、命令 ≤50、navigation ≤20、同时定时器 ≤100、`sf.rules.add` ≤200、朗读和对话框文本 ≤20000 字符、storage 键 1–200 字符且总量 ≤524288 字符、宏 ≤200 步、同时对话框/窗口 ≤8、网络请求 ≤8、文字识别 ≤2
- [ ] zip（如适用）：根目录或单一文件夹下有 `main.lua`；翻译在 `locales/<语言>.json`；≤200 个文件；宏文件放 `macros/` 时由 `sf.macros.run` 调用
- [ ] 宏 JSON：`format: "sandfly-items"`、`version: 1`、步骤块配对、条件 ≤20 项、`kind`/`field` 拼写正确

### 阶段 4：交付与验证

每次交付包含四部分：

1. **完整文件**：单文件给 `.lua`（文件名必须以 `.lua` 结尾，建议与 `id` 一致）；多文件/声音/翻译/宏给 zip；宏给 JSON 条目文件；生成器配置给逐项填写清单。给完整内容，不给片段。
2. **安装步骤**：脚本——设置 → 脚本 → **导入脚本**，或把文件"打开方式/分享"给 SandFly / 用 `https` 链接安装；装后在脚本页面**打开脚本**。也可用"添加脚本源"从公共仓库安装。宏——设置 → 宏 → 从文件导入，再到 设置 → 命令 → 宏 分配手势。脚本生成器的脚本可导出 `.zip` 再导入，且仍能继续在生成器里编辑。用了敏感权限（`passwords`/`network`/`clipboard`/`system`/`notifications`/`events`/`dialogs`/`java`）要提前说明用途。
3. **验证步骤**：2–4 条具体操作，每条写明用户做什么、预期听到/看到什么（"双击屏幕上的 X 后，应听到 Y"），与阶段 2 确认过的行为一一对应，不提代码概念。
4. **固定结尾一句**："如果哪一步不符合预期，打开脚本页面 → Log → 复制日志，把内容发给我。"

### 阶段 5：调试循环

用户报告"不行 / 失败 / 没反应"时的铁律：**先取证，后修复；没有根因不改代码。**

1. **收集证据**（缺一不可；全部用大白话向用户要，指路具体到点哪里）：
   - 现象：具体说了什么 / 没说什么 / 有没有报错提示（SandFly 会朗读报错）
   - 复现步骤：在哪个应用哪一屏、做了什么操作
   - **Log**：让用户"打开 SandFly 设置 → 脚本 → 点这个脚本的名字 → 里面的'日志' → 复制日志，全选复制发我，看不懂没关系"。Log 是第一证据——没有 Log 就先要 Log，不要猜。
   - 需要核对控件时：让用户重发"复制屏幕树"或"复制项目详情"的内容。
2. **定位根因**：对照下方错误特征表，说明你判断的根因和依据。
3. **一次只改一处**，用大白话告诉用户"问题出在哪、我改了什么"（报错原文可以附在后面）；`version` +1；重新给出验证步骤。
4. 修不好就换假设再来一轮；连续两轮无进展时，回到阶段 1 重新核对前提（包名对不对、id 有没有变、触发方式到底是什么）。

**错误特征表**（Log / 报错 → 根因 → 处理）：

| 特征 | 根因 | 处理 |
|---|---|---|
| `…needs the X permission` / `…is not used` | manifest `permissions` 缺权限，或用户关掉了该权限 | 补权限后重新导入，或在脚本页面打开权限 |
| `This waits for an answer, so call it from an event handler, a command, a timer or sf.run` | 在语音钩子或 `onActions` 本身里等待 | 慢事包进 `sf.run`；`onActions` 的慢事放进 `run` 函数 |
| `The script ran out of time` | 等待用错地方、复杂 Lua 模式、循环没有出口 | 按 Waiting 规则改；简化模式；补退出条件 |
| `That item is no longer available` | item 过期（屏幕已变化） | 用 `item:refresh()` 或重新 find |
| `The manifest declares no command …` | `sf.onCommand` 的 id 未在 manifest 声明 | 补进 `commands` |
| `Script not running on this screen` | 脚本关闭 / 当前应用不在 `apps` 里 / 正在 SandFly 自己的界面 | 逐项核对范围和开关 |
| `…no …` / `require`、`readFile`、`sf.macros.run` 报路径错 | zip 内文件或宏文件不存在 | 核对 zip 内路径与大小写 |
| 没反应，Log 里也没内容 | 触发没到达：脚本未开启 / 手势被别的命令占用 / 命令未分配 / 条件不满足 | 逐项核对绑定和条件 |
| 脚本突然整体停用 | 1 分钟 5 次错误、5 分钟 3 次超时，或一次调用卡住 20 秒 | Log 里找第一个错误，从那里修；到脚本页面重新打开 |
| `Macro stopped. Failed:/Not found:/Timed out:` | 宏某一步超时、文本不匹配、条件没满足 | 加长超时（最多 60 秒）、核对文本/类型、先加"等待直到" |

### 阶段 6：进阶（按需）

- **翻译**：zip 里放 `locales/zh-CN.json`（`{"English text": "中文"}`；复数用 `zero/one/two/few/many/other` 记录），会自动翻译脚本名、描述、设置、规则、命令等；代码里 `sf._('text', {name=...})`、`sf.ngettext(单数, 复数, n, {count=n})`。
- **按需加载**：`onDemand = true`——不占内存，命令触发时才加载，约 2 秒空闲后卸载；限制：至少一个命令，命令只能有 `id`/`title`，不能有 `apps`/`rules`/`navigation`/按钮设置，`sf.bind`/`sf.unbind` 不可用，长期监听要 `java.proxy` 且会延后卸载；状态放 `sf.storage`。见 examples/wikipedia-search.lua。
- **熄屏运行**：`keepLoaded = true`——用户在脚本页面开启"保持熄屏运行"后，熄屏时定时器/请求/`sf.speak` 仍工作（定时器不会唤醒手机）；只能用于没有 `apps`、没有 `onDemand` 的脚本。适合报时、提醒，见 examples/talking-clock.lua。
- **模块化**：`require('lib.words')` 加载 zip 内 `lib/words.lua`；`sf.readFile('data/xx.txt')` 读 zip 内文本（≤1 MB）。
- **宏与脚本联动**：zip 里放 `macros/reply.json`，脚本用 `sf.macros.run('macros/reply.json', {text=...})` 运行，`sf.macros.stop()` 停止；宏文件里的 `{name}` 占位符由 `values` 填充。注意每类步骤所需的权限。
- **v6 新能力**：`sf.feedback.mute/unmute` 临时静音（≤10 秒，触摸/切应用会自动解除）；`sf.touch.lock/unlock` 锁屏触摸（Android 13+ 且需在 SandFly 中处理手势）；`sf.device.controls/get/set/media` 控制快捷面板与媒体键；`sf.system.setTimer/setAlarm/call/message/camera`；`sf.text.replace/find/edit`；`sf.unbind`；命令的 `control` 阅读控制与 `event.direction`。
- **发布**：把 `.lua`/`.zip` 放进 GitHub/GitLab/Codeberg/Gitea/Bitbucket 公共仓库，用户在 设置 → 脚本 → 脚本源 里添加；`version` 递增后可自动更新。SandFly 官方仓库的脚本带签名，安装对话框会显示。
- **SandFly Pro**：设置 → 脚本 → 用 SandFly Pro 生成脚本，会在生成器中产出可审阅的脚本，用户选 接受 前不带 `network`/`java` 权限。

## 反面信号（随时自查）

| 想法 | 现实 |
|---|---|
| "用户说了需求，直接写吧" | 缺包名/id/触发方式的脚本就是赌。先问，问完复述确认。 |
| "id 差不多，猜一个" | 臆造 id 必然失败。要屏幕树，或先用文本匹配并注明。 |
| "失败了，整个重写一遍" | 没有根因的重写会引入新错误。先要 Log，一次只改一处。 |
| "这个报错大概是在说…" | 错误文本通常直接写明原因。逐字读，对照错误特征表。 |
| "权限多点没关系" | 权限决定用户是否信任并安装；最小够用，并说明用途。 |
| "功能复杂，一次全实现" | 拆成最小可用版本先交付验证，再迭代。 |
| "所有命令都要 input 权限" | v6 起只有带手势/按键/菜单/阅读控制分配的命令才需要；无分配命令只列任务本身的权限。 |
| "屏幕树是 JSON" | 现在复制出来的是带层级、类名、id、角色、状态的文本行；按行解析。 |
| "宏只能点点点" | v6 宏还能设置设备控件、音量、定时器、闹钟、电话、短信、值等；先查 `references/item-files.md`。 |

## 快速 API 速查

**不确定的调用一律查 `references/api.md`**（当前为完整官方 v6 参考，含全部字段、方法、手势名、限制）。

权限表：

| 权限 | 允许 |
|---|---|
| `screen` | 读屏：`sf.screen.*`、item 的读取方法、`sf.speech.last()`、文字识别、钩子/命令/动作拿到的 item（缺它则是 `nil`）；`onFocus`/`onAnnouncement`/`onTextChange`/`onContentChange`/`onScroll`/`onSelectionChange`/`onClick`/`onLongClick`/`onInputFocus`；全局脚本还需它获取前台应用（`sf.app()`、`onAppEnter`/`onAppLeave`/`onWindowChange`） |
| `actions` | 点击/滚动/输入/移动焦点：item 的动作方法、`item:tap()` 等触摸、`sf.screen.click`、`sf.touch.*`、`sf.keys.type/press`、规则里朗读以外的动作与 `buttonActions` |
| `speech` | `sf.speak`/`sf.message`、`sf.speech.stop()`、`sf.braille.show`、`sf.feedback.mute`、改写朗读的规则与钩子、`sf.rules`、`onSpeech` |
| `input` | 带 `gesture`/`keys`/`menu`/`control` 的命令、`sf.bind`/`sf.unbind`、`navigation`、`sf.commands.run`、`sf.keys.passAll`、`onActions`、规则里的动作；**v6 无分配命令不需要** |
| `network` | `sf.fetch`、`sf.translate` |
| `dialogs` | `sf.ui.*` |
| `clipboard` | `sf.clipboard.get/set` |
| `system` | `sf.system.*`、`sf.resume`、`sf.device.setVolume/setRingerMode/set/media` |
| `passwords` | 密码框文本（缺它则为 `nil`） |
| `notifications` | `onNotification` |
| `events` | `onEvent`（每个无障碍事件） |
| `java` | LuaJava 的 `java` 模块，全权访问、绕过所有限制——只建议给可信脚本 |

无需权限：声音/音调/振动、读设备信息、`sf.storage`、`sf.settings`、定时器、`sf.text`、`sf.readFile`、`require`、`sf.commands.list()`、日志、JSON、翻译。

常用分组：

- **语音与反馈**：`sf.speak(text, {interrupt, rate, pitch, language, wait})`；`sf.message(text)`（默认打断并显示到盲文）；`sf.speech.stop()/isSpeaking()/last()`；`sf.braille.show`；`sf.playSound(name)`（focus/actionable/click/longClick/scroll/listEnter/listExit/end/enter/typo/beep，或包内声音文件）、`sf.playTone`、`sf.playAudio`、`sf.vibrate`；v6：`sf.feedback.mute({speech=true,...}, ms)` 返回带 `release()` 的句柄、`sf.feedback.unmute()`。
- **屏幕**：`sf.screen.focused()/inputFocused()/root()/find(query)/findAll(query, limit)/at(x, y)/windows()/waitFor(query, timeout, interval)/click(query)/recognizeText()`；`sf.app()` → `{package, label, activity, window, meta}`。
- **item**：字段 `text/contentDescription/hint/stateDescription/id/className/role/packageName/bounds/childCount/checked/clickable/selected/enabled/editable/scrollable/range/collection/tooltip/...`；方法 `find/findAll/parent/children/child/refresh/click/longClick/scrollForward/scrollBackward/perform/setText/focus/setSelection/moveCursor/setProgress/scrollTo/nextHtmlElement/tap/doubleTap/longPress/recognizeText/labeledBy/labelFor`。
- **钩子（18 个）**：`onFocus` `onSpeech` `onNotification` `onAnnouncement`（前 4 个可改写朗读：返回 文本 / `{speak=}` / `{before=,after=}` / `{silent=true}` / `false` / nil）`onAppEnter` `onAppLeave` `onWindowChange` `onTextChange` `onContentChange` `onEvent` `onSettingChange` `onButton` `onActions`（返回 `{title, run, first}` 列表）`onScroll` `onSelectionChange` `onClick` `onLongClick` `onInputFocus`。每个返回一个取消函数。
- **输入与命令**：`sf.onCommand(id, fn(event))`（event.id/via/direction/node；在等待前返回 `false` 放行默认行为）；manifest 命令字段 `gesture`/`keys`/`menu`/`control`；`sf.bind(command, {gesture= 或 keys=})`/`sf.unbind`；`sf.commands.list()/run(id)`；`sf.touch.tap/doubleTap/longPress/swipe/gesture`（像素坐标，Android 11+）、v6 `sf.touch.lock/unlock`；`sf.keys.type/press/passAll`（Shizuku）。
- **界面**（都要 `dialogs`）：`sf.ui.alert/confirm/prompt/choose/text`（等待）；`sf.ui.dialog/window({title, items, onClose})` 立即返回 form；form 方法 `get/values/set/add/remove/focus/setTitle/setSummary/close/wait`；表单项类型 `label/heading/edit/switch/list/items/slider/button`。
- **数据**：`sf.storage.get(key, fallback)/set/remove/keys/clear`；`sf.settings.get/all/set/setOptions/setTitle/setSummary`；`sf.rules.add/remove/clear`；`json.encode/decode`（`json.null`）。
- **系统/网络**：`sf.fetch(url, {method, headers, body, timeout})` → `{status, statusText, ok, headers, body}` + `:json()`/`:text()`（https、请求体 ≤1 MB、响应 ≤5 MB、超时 ≤60 秒、并发 ≤8）；`sf.system.back/home/recents/notifications/quickSettings/powerDialog/lockScreen/takeScreenshot/allApps/openApp/openUrl/share/openSettings/startActivity/sendBroadcast/apps`，v6 `setTimer/setAlarm/call/message/camera`；`sf.device.info/battery/network/volume/setVolume/ringerMode/setRingerMode`，v6 `controls/get/set/media`；`sf.translate(text, {from, to})`。
- **文本与宏（v6）**：`sf.text.replace(text, pattern, with)/find(text, pattern)/edit(text, edits)`；`sf.macros.run(file, values)/stop()`。
- **杂项**：`sf.setTimeout/setInterval/clearTimer(fn, ms, ...)/sleep(ms)/run(fn)/clock()`；`sf.readFile`；`require`；`sf._/ngettext/locale/language`；`sf.apiVersion/manifest()`；`print(...)`、`sf.log(...)` 与 `sf.log.debug/info/warn/error(...)` 写入脚本页面的 Log。

## 常见陷阱（写完必对照）

1. 语音钩子（onFocus 等）里调用等待函数 → 直接报错。先 `sf.run(...)` 再做慢事。
2. `onActions` 本身超时（50 毫秒）→ 动作不进菜单。只做快速判断，慢事放进 `run` 函数。
3. 忘记 `refresh()`：item 是快照，屏幕变化后旧引用上的 `find`/动作可能落空或报错。
4. manifest 里写了表达式（`'a'..'b'`、函数调用、变量）或规则里写错字段名 → 安装解析失败。全写字面值。
5. 权限漏了：调用处报错；钩子/规则被静默跳过（Log 里有警告）。v6 无分配命令不必加 `input`，但带手势的命令必须有。
6. 范围搞错：带 `apps` 的脚本只在列出的应用生效；省略 `apps` 则所有应用生效。测试时确认范围。
7. SandFly 自己的界面上脚本不生效，且需要 `screen`/`actions`/`system`/`dialogs` 权限的调用在那里会报错——这是设计行为，保证脚本管理界面永远可用。
8. `sf.onCommand` 的 id 没在 manifest `commands` 里声明 → 脚本报错（引擎会校验）。
9. 无 `sf` 前缀的按键（如 `'u'`）在编辑框有输入焦点时不触发，这是有意设计。
10. 长文本上复杂的 Lua 模式（多个 `.-`、`.*`）可能跑满 2 秒且中途无法中断——保持模式简单。
11. 每次改动忘记递增 `version` → 用户的脚本自动更新不会生效。
12. 宏"点击项目"等不到项目时整个宏停止——把超时设够（最长 60 秒），核对文本/类型，或先加"等待直到"。
13. 触摸类 API（`sf.touch.*`、`item:tap()`）需要 Android 11+；`sf.keys.*` 与按键宏需要 Shizuku 运行并放行 SandFly；`sf.touch.lock` 还要 Android 13+ 和"在 SandFly 中处理手势"。
14. `sf.device.set`、`sf.fetch`、`sf.macros.run` 可能抛错——用 `pcall` 包住并向用户播报失败原因。
15. 静音和触摸锁在脚本卸载、报错、切应用或用户触摸/按键时会自动结束——别把它们当长期状态。

## 参考与示例

| 文件 | 内容 |
|---|---|
| `references/api.md` | 完整官方脚本 API 参考（v6，权威：全部字段、方法、手势名、限制） |
| `references/item-files.md` | 宏等条目文件的 JSON 格式（写宏时用；含官方参考未列出的 `do` 步骤补充） |
| `references/macros.md` | 用户指南的宏章节：步骤名、条件、录制与运行方式 |
| `examples/example-plugin.lua` | 官方入门：`onAppEnter` + 设置 + 存储 |
| `examples/app-tweaks.lua` | 单应用定制综合：manifest 规则 + onFocus 改朗读 + onActions + 命令 + 对话框 + 存储 |
| `examples/wikipedia-search.lua` | `onDemand` 按需加载 + `sf.fetch` 网络请求 + 选择对话框（v6 修正版） |
| `examples/notepad.lua` | `sf.ui.window` 完整小应用：表单、列表、行动作、动态界面 |
| `examples/talking-clock.lua` | `keepLoaded` 熄屏运行 + 列表设置 + `onSettingChange` + 定时器 |

## 与 SandFly 源码仓库配合（工作区里有 SandFly 仓库时）

- `docs/scripting.md` 是脚本 API 权威文档（本技能的 `references/api.md` 是它的副本）；有出入以仓库最新版为准。`docs/scripting/examples/` 是官方示例。
- `docs/reference/item-files.md` 是条目文件权威参考；`docs/user-guide/en/16-macros.md` 说明宏界面；`docs/user-guide/en/20-scripts.md` 说明脚本生成器。
- `sf.commands.run` 可用的命令 id：见 `talkback/src/main/java/com/google/android/accessibility/talkback/commands/Commands.kt`，或脚本里 `sf.commands.list()`。
- 脚本引擎实现：`talkback/src/phone/java/com/google/android/accessibility/talkback/scripting/`（`ScriptManifest.kt` 里的 `API_VERSION` 常量可确认当前版本，当前为 6）。

## 版本兼容性

本技能同步于 2026-11-24，基于 SandFly 0.7.0 的脚本 API v6。若用户的 SandFly 较旧：让脚本在运行时用 `sf.apiVersion` 判断并降级（v6 新增调用换成低版本写法），或建议用户升级 SandFly。v2–v6 只添加、不改旧调用；`minApiVersion` 高于设备版本时仍可安装，但页面和日志会警告部分功能可能不可用。
