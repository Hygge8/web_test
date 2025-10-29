# 贡献指南

感谢您对AI原生Web应用项目的关注!我们欢迎所有形式的贡献,包括但不限于:

- 报告Bug
- 提出新功能建议
- 改进文档
- 提交代码修复或新功能

## 行为准则

参与本项目即表示您同意遵守我们的行为准则。请保持友善、尊重和专业。

## 如何贡献

### 报告Bug

如果您发现了Bug,请通过GitHub Issues报告,并包含以下信息:

1. **Bug描述**: 清晰简洁地描述问题
2. **复现步骤**: 详细说明如何复现该问题
3. **期望行为**: 描述您期望发生什么
4. **实际行为**: 描述实际发生了什么
5. **环境信息**: 
   - 操作系统
   - 浏览器版本
   - Node.js版本
   - 其他相关信息
6. **截图**: 如果适用,请添加截图

### 提出功能建议

我们欢迎新功能建议!请通过GitHub Issues提交,并包含:

1. **功能描述**: 清晰描述建议的功能
2. **使用场景**: 说明该功能的使用场景
3. **预期效果**: 描述该功能将如何改善用户体验
4. **实现思路**: 如果有,可以提供实现思路

### 提交代码

#### 开发环境设置

1. Fork本仓库
2. 克隆您的Fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/web_test.git
   cd web_test
   ```

3. 添加上游仓库:
   ```bash
   git remote add upstream https://github.com/Hygge8/web_test.git
   ```

4. 安装依赖:
   ```bash
   pnpm install
   ```

5. 配置环境变量:
   ```bash
   cp .env.example .env
   # 编辑.env文件,填入必要配置
   ```

6. 初始化数据库:
   ```bash
   pnpm db:push
   ```

7. 启动开发服务器:
   ```bash
   pnpm dev
   ```

#### 开发流程

1. **创建分支**: 从`develop`分支创建特性分支
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/your-feature-name
   ```

2. **编写代码**: 
   - 遵循项目的代码规范
   - 编写清晰的注释
   - 确保代码通过类型检查

3. **测试**: 确保所有测试通过
   ```bash
   pnpm test
   ```

4. **提交代码**: 使用清晰的提交信息
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

5. **推送分支**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **创建Pull Request**:
   - 在GitHub上创建PR
   - 填写PR模板
   - 等待代码审查

#### 提交信息规范

我们使用[Conventional Commits](https://www.conventionalcommits.org/)规范:

- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码格式调整(不影响功能)
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具链相关

示例:
```
feat: add voice transcription feature
fix: resolve chat message display issue
docs: update API documentation
```

#### 代码规范

1. **TypeScript**: 
   - 使用严格的类型定义
   - 避免使用`any`类型
   - 为函数添加返回类型

2. **React组件**:
   - 使用函数式组件
   - 使用Hooks管理状态
   - 组件名使用PascalCase

3. **样式**:
   - 使用Tailwind CSS工具类
   - 遵循响应式设计原则
   - 保持设计一致性

4. **命名规范**:
   - 文件名: kebab-case (例如: `chat-page.tsx`)
   - 组件名: PascalCase (例如: `ChatPage`)
   - 函数名: camelCase (例如: `sendMessage`)
   - 常量: UPPER_SNAKE_CASE (例如: `MAX_FILE_SIZE`)

5. **代码格式化**:
   ```bash
   pnpm format
   ```

#### Pull Request检查清单

在提交PR前,请确保:

- [ ] 代码遵循项目规范
- [ ] 所有测试通过
- [ ] 添加了必要的文档
- [ ] 提交信息清晰明确
- [ ] 没有合并冲突
- [ ] PR描述清晰完整

### 文档贡献

文档改进同样重要!您可以:

- 修正错别字
- 改进表述
- 添加示例
- 翻译文档

## 分支管理

项目使用以下分支策略:

- `main`: 生产分支,保持稳定
- `develop`: 开发分支,用于集成新功能
- `feature/*`: 功能分支
- `fix/*`: 修复分支
- `docs/*`: 文档分支

## 代码审查

所有PR都需要经过代码审查。审查者会关注:

- 代码质量和可维护性
- 是否遵循项目规范
- 是否有充分的测试
- 是否有必要的文档

## 发布流程

1. 功能开发在`feature`分支
2. 合并到`develop`分支进行集成测试
3. 从`develop`创建`release`分支
4. 测试通过后合并到`main`
5. 打tag并发布

## 获取帮助

如果您有任何问题:

- 查看[README.md](README.md)
- 搜索[Issues](https://github.com/Hygge8/web_test/issues)
- 创建新Issue询问

## 许可证

通过贡献代码,您同意您的贡献将在[MIT许可证](LICENSE)下发布。

---

再次感谢您的贡献!🎉

