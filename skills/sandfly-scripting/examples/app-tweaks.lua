-- 应用微调（App tweaks）示例 —— 为单个应用改善读屏体验的最常见模式。
--
-- 演示了：
--   * manifest 里的 rules / commands / navigation / settings
--   * sf.onFocus 在朗读前改写文本（30 毫秒内返回，不能等待）
--   * sf.onActions 给项目加自定义 Actions 菜单项
--   * 命令里移动焦点、弹对话框、用 sf.storage 记数据
--
-- 使用方法：把 apps 里的包名、rules 里的 view id 换成目标应用的实际值。
-- 获取途径：SandFly 的"检查当前聚焦项"（Inspect focused item）和
-- "复制屏幕树"（Copy screen tree）命令；或直接用 textContains 按文本匹配。

local manifest = {
  id = 'example.app-tweaks',
  name = 'App tweaks example',
  version = '1.1',
  author = 'You',
  description = 'Example: rename and hide items, add a command and Actions menu items in one app.',
  homepage = 'https://github.com/aaron-gh/SandFly',
  -- sf.message 等是 *Version 2* 的 API，所以 minApiVersion 是 2；
  -- testedApiVersion 填实际测试过的最高版本（SandFly 0.7.0 的脚本 API 是 6）。
  minApiVersion = 2,
  testedApiVersion = 6,
  -- 只在这个应用里运行（换成目标应用的包名）。省略 apps 则在所有应用运行。
  apps = 'com.example.mail',
  -- 权限按实际用到的填，能少则少。这里：
  -- screen 读屏、speech 改朗读、actions 点击和移焦点、input 命令和 onActions、dialogs 对话框。
  permissions = { 'screen', 'speech', 'actions', 'input', 'dialogs' },
  rules = {
    -- id 用短形式或完整形式；不知道 id 时按文本/描述匹配。
    { id = 'archive_button', label = '归档' },
    { match = { className = 'ImageView', contentDescription = 'More options' }, label = '更多选项' },
    -- 整行合并为一个项目朗读；双击行时实际按下行内的 open_button。
    { id = 'message_row', group = true, activate = { id = 'open_button' } },
    -- 隐藏广告；'all' 表示连同内部元素一起跳过。
    { match = { textContains = 'Advertisement' }, hide = 'all' },
  },
  commands = {
    -- gesture 是手势列表里的精确名称；keys 以 sf 为修饰键。
    { id = 'unread', title = 'Next unread', gesture = 'swipeDownThenLeft', keys = 'sf+u' },
    { id = 'stats', title = 'Open statistics', menu = true },
  },
  navigation = {
    -- 成为一个阅读控制：上下扫选择它后，上下滑在未读行之间跳转。
    { title = 'Unread messages', match = { className = 'UnreadRow' } },
  },
  settings = {
    -- 显示在脚本页面的设置屏幕，sf.settings.get('briefSender') 读取。
    { key = 'briefSender', type = 'switch', title = 'Say the sender first', default = true },
  },
}

-- 在 SandFly 朗读聚焦项之前改写要说的话。
-- 语音钩子必须在 30 毫秒内返回；需要等待的工作用 sf.run(function() ... end) 另起任务。
sf.onFocus(function(item, text)
  if not sf.settings.get('briefSender') then
    return
  end
  -- 只在邮件列表的行上生效。id 可能是短形式或完整形式（com.example.mail:id/message_row），
  -- 用 match('message_row$') 两种都能匹配。
  if item.id and item.id:match('message_row$') and item.text then
    local sender, subject = item.text:match('^([^,]+),%s*([^,]+)')
    if sender then
      -- 返回 { before = ... } 在原朗读前加一段；也可以返回 { speak = '...' } 整句替换，
      -- 或 { silent = true } / false 什么都不说，或什么也不返回表示不修改。
      return { before = sender .. ', ' .. (subject or '') }
    end
  end
end)

-- 给 Actions 菜单加项目。onActions 本身必须在 50 毫秒内返回、不能等待；
-- 每个动作的 run 收到这个项目，作为任务运行，可以等待。
-- Version 5：动作加 first = true 可以排到应用自带动作之前。
sf.onActions(function(item)
  if item.id and item.id:match('message_row$') then
    return {
      {
        title = 'Mark as read',
        run = function(row)
          local button = row:find({ id = 'read_button' })
            or row:find({ textContains = 'Mark as read' })
          if button and button:click() then
            sf.message('Marked as read') -- 打断当前朗读并显示到盲文显示器（Version 2 API）
          else
            sf.speak('Button not found')
          end
        end,
      },
    }
  end
end)

-- 命令处理函数收到 event 表：event.id、event.via（'gesture'、'keys'、'menu'、'control'…）、
-- event.direction、event.node（聚焦项）。返回 false（在等待前）让手势恢复 SandFly 默认行为。
-- 注意：这里的 id 必须已在 manifest 的 commands 里声明，否则脚本报错。
sf.onCommand('unread', function(event)
  -- 真实实现可以比较 event.node 和各行 bounds 的位置跳到下一个；
  -- 这里只演示查找和移焦点。
  local row = sf.screen.find({ className = 'UnreadRow' })
  if row then
    row:focus()
  else
    sf.speak('No unread messages')
  end
end)

sf.onCommand('stats', function()
  local app = sf.app()
  if not app or not app.package then
    return
  end
  -- sf.storage 在脚本卸载（如切走应用）后仍保留，上限 524,288 字符。
  local counts = sf.storage.get('opens', {})
  counts[app.package] = (counts[app.package] or 0) + 1
  sf.storage.set('opens', counts)
  -- 对话框会等待，命令回调里可以等待。
  sf.ui.alert(('Opened %d times.'):format(counts[app.package]), { title = 'Statistics' })
end)

print('App tweaks example loaded, API version ' .. sf.apiVersion)
