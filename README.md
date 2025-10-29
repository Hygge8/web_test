# AI原生Web应用

<div align="center">

![AI原生Web应用](https://img.shields.io/badge/AI-Native%20Web%20App-blue)
![React](https://img.shields.io/badge/React-19-61dafb)
![TypeScript](https://img.shields.io/badge/TypeScript-5.0-3178c6)
![License](https://img.shields.io/badge/license-MIT-green)

一个功能完整的AI原生Web应用,集成了智能对话、内容生成、语音识别和数据分析等多种AI能力。

[在线演示](#) | [功能特性](#功能特性) | [快速开始](#快速开始) | [技术栈](#技术栈)

</div>

---

## 📋 目录

- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [环境变量](#环境变量)
- [开发指南](#开发指南)
- [API文档](#api文档)
- [部署](#部署)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

## ✨ 功能特性

### 🤖 AI智能对话
- 支持创建多个对话会话
- 智能上下文理解和记忆
- 实时流式响应
- 对话历史自动保存

### 🎨 智能内容生成
- **文本生成**: 使用先进的LLM模型生成高质量文本内容
- **图像生成**: 基于文本描述生成精美图像
- 支持自定义提示词
- 生成历史记录管理

### 🎤 语音转文字
- 支持多种音频格式 (MP3, WAV, M4A, OGG, WEBM)
- 高精度语音识别
- 支持多语言识别
- 最大支持16MB文件

### 📊 数据分析与可视化
- 智能数据分析
- 自动生成可视化图表
- 支持多种图表类型
- AI驱动的数据洞察

### 📝 历史记录管理
- 完整的操作历史追踪
- 分类浏览和搜索
- 一键回顾和复用

## 🛠 技术栈

### 前端
- **框架**: React 19
- **语言**: TypeScript
- **样式**: Tailwind CSS 4
- **UI组件**: shadcn/ui
- **状态管理**: tRPC React Query
- **路由**: Wouter
- **图表**: Chart.js

### 后端
- **运行时**: Node.js 22
- **框架**: Express 4
- **API**: tRPC 11
- **认证**: Manus OAuth
- **数据序列化**: SuperJSON

### 数据库
- **数据库**: MySQL / TiDB
- **ORM**: Drizzle ORM
- **迁移**: Drizzle Kit

### AI集成
- **LLM**: 内置大语言模型服务
- **图像生成**: 内置图像生成服务
- **语音识别**: Whisper API

### 开发工具
- **构建工具**: Vite 7
- **包管理**: pnpm
- **代码规范**: ESLint + Prettier
- **测试**: Vitest

## 🚀 快速开始

### 前置要求

- Node.js >= 22.0.0
- pnpm >= 10.0.0
- MySQL 8.0+ 或 TiDB

### 安装

```bash
# 克隆仓库
git clone https://github.com/Hygge8/web_test.git
cd web_test

# 安装依赖
pnpm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件,填入必要的配置

# 初始化数据库
pnpm db:push

# 启动开发服务器
pnpm dev
```

应用将在 http://localhost:3000 启动。

## 📁 项目结构

```
web_test/
├── client/                 # 前端代码
│   ├── public/            # 静态资源
│   └── src/
│       ├── components/    # UI组件
│       ├── pages/         # 页面组件
│       ├── hooks/         # 自定义Hooks
│       ├── lib/           # 工具库
│       └── contexts/      # React上下文
├── server/                # 后端代码
│   ├── _core/            # 核心功能
│   ├── db.ts             # 数据库查询
│   └── routers.ts        # tRPC路由
├── drizzle/              # 数据库Schema和迁移
│   └── schema.ts         # 数据表定义
├── shared/               # 前后端共享代码
├── storage/              # S3存储辅助函数
└── package.json
```

## 🔐 环境变量

项目使用以下环境变量(由Manus平台自动注入):

```env
# 数据库
DATABASE_URL=mysql://...

# 认证
JWT_SECRET=...
OAUTH_SERVER_URL=...
VITE_OAUTH_PORTAL_URL=...

# AI服务
BUILT_IN_FORGE_API_URL=...
BUILT_IN_FORGE_API_KEY=...

# 应用配置
VITE_APP_TITLE=AI原生Web应用
VITE_APP_LOGO=...
```

## 💻 开发指南

### 开发命令

```bash
# 启动开发服务器
pnpm dev

# 构建生产版本
pnpm build

# 运行生产服务器
pnpm start

# 数据库迁移
pnpm db:push

# 代码格式化
pnpm format

# 运行测试
pnpm test
```

### 添加新功能

1. **定义数据库Schema** (`drizzle/schema.ts`)
2. **创建数据库查询函数** (`server/db.ts`)
3. **添加tRPC路由** (`server/routers.ts`)
4. **创建前端页面** (`client/src/pages/`)
5. **更新路由配置** (`client/src/App.tsx`)

### 代码规范

项目遵循以下代码规范:

- 使用TypeScript进行类型安全开发
- 遵循ESLint和Prettier配置
- 使用tRPC确保前后端类型同步
- 组件使用函数式编程风格
- 优先使用shadcn/ui组件

## 📚 API文档

### tRPC路由

#### 认证 (`auth`)
- `auth.me` - 获取当前用户信息
- `auth.logout` - 退出登录

#### 对话 (`chat`)
- `chat.createConversation` - 创建新对话
- `chat.getConversations` - 获取对话列表
- `chat.getMessages` - 获取对话消息
- `chat.sendMessage` - 发送消息
- `chat.deleteConversation` - 删除对话

#### 内容生成 (`generate`)
- `generate.text` - 生成文本
- `generate.image` - 生成图像
- `generate.getHistory` - 获取生成历史

#### 语音转录 (`transcription`)
- `transcription.create` - 创建转录
- `transcription.getHistory` - 获取转录历史

#### 数据分析 (`analysis`)
- `analysis.create` - 创建分析
- `analysis.getHistory` - 获取分析历史
- `analysis.getById` - 获取指定分析

#### 存储 (`storage`)
- `storage.uploadAudio` - 上传音频文件

## 🚢 部署

### 使用Manus平台部署

1. 保存项目检查点
2. 点击"发布"按钮
3. 配置域名(可选)
4. 完成部署

### 手动部署

```bash
# 构建项目
pnpm build

# 设置环境变量
export DATABASE_URL=...
export JWT_SECRET=...
# ... 其他环境变量

# 启动生产服务器
pnpm start
```

## 🤝 贡献指南

我们欢迎所有形式的贡献!请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详细信息。

### 贡献流程

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [React](https://react.dev/) - 前端框架
- [tRPC](https://trpc.io/) - 端到端类型安全API
- [Tailwind CSS](https://tailwindcss.com/) - CSS框架
- [shadcn/ui](https://ui.shadcn.com/) - UI组件库
- [Drizzle ORM](https://orm.drizzle.team/) - TypeScript ORM
- [Manus](https://manus.im/) - AI原生应用平台

## 📞 联系方式

- 项目仓库: [https://github.com/Hygge8/web_test](https://github.com/Hygge8/web_test)
- 问题反馈: [Issues](https://github.com/Hygge8/web_test/issues)

---

<div align="center">

**[⬆ 回到顶部](#ai原生web应用)**

Made with ❤️ by [Hygge8](https://github.com/Hygge8)

</div>

