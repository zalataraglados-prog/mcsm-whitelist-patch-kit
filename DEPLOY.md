# 部署说明

本补丁针对当前这套两段式结构：
- 面板机：运行 `MCSManager Web + Daemon`
- 游戏节点：运行远程 `MCSManager Daemon + Minecraft 实例`

当前仓库已经验证过的目标版本：
- `MCSManager Panel 10.16.1`
- `MCSManager Daemon 4.16.1`

---

## 一、当前部署流程

### 1. 面板机安装补丁

适用机器：
- 运行 `mcsm-web`
- 运行 `mcsm-daemon`

作用：
- 安装面板前端白名单表格
- 安装面板机本地 daemon 补丁

Linux 命令：
```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.sh | bash
```

Windows Server 命令：
```powershell
curl.exe -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

### 2. 游戏节点安装 daemon 补丁

适用机器：
- 只运行 `mcsm-daemon`
- 承载实际 Minecraft 实例

作用：
- 让远程 daemon 支持 `whitelist.json` 解析
- 识别 `banned-players.json`
- 在离线模式下自动补全 UUID

Linux 命令：
```bash
curl -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install-daemon.sh | bash
```

Windows Server 命令：
```powershell
curl.exe -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install-daemon.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

---

## 二、为什么要分两段

这不是单机结构：
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

Linux 需要：
- `systemd`
- `bash`
- `curl`
- `python3`
- `tar`
- `git`（优先使用；没有时回退 tarball）

Windows 需要：
- `PowerShell 5.1+` 或 `PowerShell 7+`
- `curl.exe`
- `Expand-Archive`
- `git`（优先使用；没有时回退 `main.zip`）

脚本会自动：
- 校验面板和 daemon 版本
- 备份原文件
- 覆盖补丁文件
- 重启服务
- 执行健康检查

### 游戏节点

Linux 需要：
- `systemd`
- `bash`
- `curl`
- `python3`
- `tar`
- `git`

Windows 需要：
- `PowerShell 5.1+` 或 `PowerShell 7+`
- `curl.exe`
- `Expand-Archive`
- `git`

脚本会自动尝试探测：
- MCSManager 安装目录
- daemon 对应的 `node` 运行时
- 对应服务名

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
- `mcsm-daemon` 处于运行状态
- `whitelist.json` 读取正常
- `banned-players.json` 状态能正确映射到“是否封禁”

---

## 五、回滚

### 面板机回滚

Linux：
```bash
bash scripts/rollback.sh
```

Windows：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback.ps1
```

作用：
- 恢复最近一次面板机备份
- 重启面板相关服务

### 游戏节点回滚

Linux：
```bash
bash scripts/rollback-daemon.sh
```

Windows：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback-daemon.ps1
```

作用：
- 恢复最近一次 daemon 备份
- 重启 daemon 服务

---

## 六、当前功能边界

### 已支持

- `whitelist.json` 解析为交互表格
- 删除行
- 封禁状态展示
- 离线模式自动补 UUID

### 当前未做

- 在白名单页直接编辑封禁状态并同步写 `banned-players.json`
- 多节点批量联动安装
- 单条完全相同的 Linux / Windows 通用命令

---

## 七、Windows Server 兼容说明

### 1. 补丁逻辑是否兼容

**兼容。**

原因：
- 白名单解析逻辑是 `Node.js` 代码
- 前端白名单表格也是跨平台前端代码
- Minecraft 白名单与封禁文件格式本身不区分 Linux / Windows

所以如果是同版本的 `MCSManager 10.16.1 / 4.16.1`，补丁后的 `app.js` 逻辑本身可以工作。

### 2. 当前 Linux 一键脚本是否兼容

**不兼容。**

原因：
- 现有 `.sh` 脚本依赖 `bash`
- Linux 服务管理依赖 `systemd`
- 路径探测也是按 Linux 写的

所以：
- `scripts/install.sh`
- `scripts/install-daemon.sh`
- `scripts/rollback.sh`
- `scripts/rollback-daemon.sh`

不能直接在 Windows Server 上跑。

### 3. 当前 Windows 一键脚本是否兼容

**兼容。**

当前仓库已补充：
- `scripts/install.ps1`
- `scripts/install-daemon.ps1`
- `scripts/rollback.ps1`
- `scripts/rollback-daemon.ps1`
- `scripts/healthcheck.ps1`
- `scripts/healthcheck-daemon.ps1`

这些脚本会：
- 优先 `git clone` 拉仓库
- 没有 `git` 时回退 `main.zip`
- 自动探测安装目录
- 自动探测服务名与 `node.exe`
- 完成备份、覆盖、重启、健康检查

### 4. 自动探测失败时怎么处理

如果自动探测失败，手工指定根目录：

```powershell
$env:MCSM_ROOT = "D:\MCSManager"
curl.exe -fsSL https://raw.githubusercontent.com/zalataraglados-prog/mcsm-whitelist-patch-kit/main/scripts/install.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

### 5. 关于“curl 指令两用”

当前可以做到：
- 同一个 GitHub 仓库
- 同一种 `curl` 拉取方式
- Linux 走 `| bash`
- Windows 走 `| powershell`

当前**不建议**做成“同一条完全相同命令同时兼容 bash 和 PowerShell”的 polyglot 脚本，原因是：
- 调试困难
- 出错面大
- 生产环境回滚和定位都不干净

结论：
- **补丁逻辑兼容 Windows Server**
- **Linux 与 Windows 现在都有一键安装脚本**
- **但不是同一条完全相同的命令**

---

## 八、仓库地址

```text
https://github.com/zalataraglados-prog/mcsm-whitelist-patch-kit
```
