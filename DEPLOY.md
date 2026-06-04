# 部署说明

本补丁针对当前这套两段式架构：

- 面板机：运行 `MCSManager Web + Daemon`
- 游戏节点：运行远程 `MCSManager Daemon + Minecraft 实例`

当前仓库已经验证过的目标版本：

- `MCSManager Panel 10.16.1`
- `MCSManager Daemon 4.16.1`

---

## 一、当前部署流程

### 1. 面板机安装补丁

适用机器：

- 运行 `mcsm-web.service`
- 运行 `mcsm-daemon.service`

作用：

- 安装面板前端白名单表格
- 安装面板机本地 daemon 补丁

命令：

```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.sh | bash
```

### 2. 游戏节点安装 daemon 补丁

适用机器：

- 只运行 `mcsm-daemon.service`
- 承载实际 Minecraft 实例

作用：

- 让远程 daemon 支持 `whitelist.json` 解析
- 识别 `banned-players.json`
- 在离线模式下自动补全 UUID

命令：

```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install-daemon.sh | bash
```

---

## 二、为什么要分两段

这不是单机结构。

- 白名单表格前端在面板机
- 白名单真实读写逻辑在游戏节点 daemon

如果只装面板机：

- 页面能出现
- 但远程节点不一定具备白名单解析能力

如果只装游戏节点：

- daemon 能解析
- 但面板前端没有白名单表格入口

所以当前生产结构必须分两段安装。

---

## 三、安装前检查

### 面板机

需要满足：

- Linux
- `systemd`
- `bash`
- `curl`
- `python3`
- `tar`
- `git`（优先使用；没有时回退 tarball）
- MCSManager 安装目录可自动探测

脚本会自动：

- 校验面板和 daemon 版本
- 备份原文件
- 覆盖补丁文件
- 重启服务
- 执行健康检查

### 游戏节点

需要满足：

- Linux
- `systemd`
- `bash`
- `curl`
- `python3`
- `tar`
- `git`
- 节点上存在 `mcsm-daemon.service`

脚本会自动从 `systemd` 的 `ExecStart` 中解析 node 路径，不要求 `node` 在全局 `PATH`。

---

## 四、安装后验证

### 面板机验证

检查：

- 面板可以打开
- 实例进入 `服务端配置`
- 能看到 `whitelist.json`

预期功能：

- 表格列：`名称`、`UUID`、`是否封禁`、`操作`
- 支持新增行
- 支持删除行
- 离线模式下，名字有值而 UUID 为空时，保存后自动补全离线 UUID

### 游戏节点验证

检查：

- `mcsm-daemon.service` 为 `active`
- `whitelist.json` 读取正常
- `banned-players.json` 状态能正确映射到“是否封禁”

---

## 五、回滚

### 面板机回滚

如果当前目录就是仓库副本：

```bash
bash scripts/rollback.sh
```

作用：

- 恢复最近一次面板机备份
- 重启 `mcsm-web.service`
- 重启 `mcsm-daemon.service`

### 游戏节点回滚

如果当前目录就是仓库副本：

```bash
bash scripts/rollback-daemon.sh
```

作用：

- 恢复最近一次 daemon 备份
- 重启 `mcsm-daemon.service`

---

## 六、当前功能边界

### 已支持

- `whitelist.json` 解析为交互表格
- 删除行
- 封禁状态展示
- 离线模式自动补 UUID

### 当前未做

- 在白名单页直接编辑封禁状态并同步写 `banned-players.json`
- 多节点批量自动联动安装
- Windows Server 一键安装脚本

---

## 七、Windows Server 兼容说明

### 1. 补丁逻辑是否兼容

**大体兼容。**

原因：

- 白名单解析逻辑是 Node.js 代码
- 前端白名单表格也是跨平台前端代码
- Minecraft 白名单与封禁文件格式本身不区分 Linux / Windows

所以：

- 如果是 `MCSManager 10.16.1 / 4.16.1`
- 如果 Windows 节点也是相同版本的 daemon
- 那么补丁后的 `app.js` 逻辑本身可以工作

### 2. 当前一键脚本是否兼容

**当前不兼容。**

原因：

- 现有脚本依赖：
  - `bash`
  - `systemd`
  - Linux 路径探测
  - `cp` / `tar` / `curl`
- Windows Server 通常使用：
  - PowerShell
  - NSSM / 计划任务 / 手工启动
  - 非 `systemd`

所以现在仓库里的：

- `install.sh`
- `install-daemon.sh`
- `rollback.sh`
- `rollback-daemon.sh`

都按 Linux 写的，不能直接在 Windows Server 上跑。

### 3. Windows Server 怎么处理

当前有两种方式：

- 方式 A：手工覆盖补丁文件
  - 替换 Windows 上的 daemon `app.js / app.js.map`
  - 如果需要面板前端，也替换 `web/public/index.html` 和 `web/public/assets`

- 方式 B：后续补一套 PowerShell 安装器
  - 例如：
    - `install.ps1`
    - `install-daemon.ps1`
    - `rollback.ps1`

### 4. 当前结论

- **补丁逻辑兼容 Windows Server**
- **现有一键安装脚本不兼容 Windows Server**
- 如果你后面要把 MC 游戏节点放到 Windows Server，我建议再专门补一套 `PowerShell` 部署脚本

---

## 八、仓库地址

```text
https://github.com/zalataraglados-prog/mcsm-whitelist-patch-kit
```
