# HealthMi Sleep 安装与使用

## 1. 准备

- 一台 Mac，安装 Xcode 16 或更高版本；
- iPhone 已开启开发者模式；
- Apple Developer 账号。写入 HealthKit 的真机签名建议使用付费开发者团队；
- 小米运动健康账号及可用的登录 Cookie。

仓库已包含可直接打开的 `HealthMi.xcodeproj`。如果修改了 `project.yml` 或新增源码文件，也可以先运行：

```bash
brew install xcodegen
xcodegen generate
```

## 2. 真机安装

1. 用 Xcode 打开 `HealthMi.xcodeproj`；
2. 选中 `HealthMi` Target → `Signing & Capabilities`；
3. 将 Bundle Identifier 改为你账号下唯一的值，例如 `com.yourname.HealthMiSleep`；
4. 在 Team 中选择你的 Apple Developer 团队，确认 HealthKit Capability 已存在；
5. 用数据线或无线调试连接 iPhone，选择该 iPhone 作为运行目标；
6. 点击 Run。首次安装若提示开发者不受信任，按 iPhone 系统提示完成信任。

命令行真机构建示例：

```bash
xcodebuild -project HealthMi.xcodeproj -scheme HealthMi \
  -destination 'platform=iOS,id=<设备UDID>' \
  PRODUCT_BUNDLE_IDENTIFIER=com.yourname.HealthMiSleep \
  DEVELOPMENT_TEAM=<团队ID> \
  -allowProvisioningUpdates build
```

## 3. 首次使用

1. 打开 App，使用内置 WebView 登录小米账号；
2. 允许 App 读取和写入 Apple 健康数据；
3. 选择小米账号所在区域；
4. 首次建议回填最近 30 天，并确保“睡眠、呼吸频率、心率变异性”已开启；
5. 同步完成后，从首页进入“睡眠模式分析”；
6. 设置每晚目标时长，即可查看 30 天趋势分、规律性、睡眠效率、分期结构和逐晚明细。

如果旧版本同步的数据没有显示“小米睡眠分”，执行一次“重新回填 30 天”即可写入新版睡眠元数据。已有 HealthKit 样本会按外部 ID 去重，不会重复写入。

## 4. 常见问题

### 同步提示 code=70016

小米 `passToken` 已过期。回到 App 更新小米凭据后重试。

### 睡眠分析为空

- 检查 Apple 健康中是否已有睡眠分期；
- 在 App 的同步类别中开启“睡眠”；
- 检查 iPhone 的“设置 → 健康 → 数据访问与设备 → HealthMi”读取权限；
- 至少需要一晚、90 分钟以上且含睡着分期的记录。

### 睡眠时长与小米 App 略有差异

HealthMi 按 HealthKit 中实际分期的时间轴去重汇总，并按起床日归属。小米 App 若采用不同的四舍五入、午睡或缺失分期规则，结果可能有少量差异。

## 5. 隐私与健康提示

账号凭据只存放在设备 Keychain。项目调用的是小米非官方私有接口，接口可能变化，请勿高频请求或分发自己的 `passToken`。

睡眠趋势分用于个人趋势观察，不诊断失眠、睡眠呼吸暂停或其他疾病。若持续出现明显不适、憋醒或呼吸异常，请咨询专业医务人员。
