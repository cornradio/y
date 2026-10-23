# y
零依赖的终端文件浏览器(目前支持 macos、windows）
安装后新开终端，或直接输入 `y` 启动。
安装方式请滚动到下面章节查看。

macos 截图

<img width="600" height="" alt="image" src="https://github.com/user-attachments/assets/3cc74f96-1fbb-44e3-9ce4-e163200807e9" />

win 截图

<img width="600" height="" alt="image" src="https://github.com/user-attachments/assets/562093e5-9fca-47a4-b66c-fccdcdcceeaf" />


# y （formacos）

一个零依赖的 macOS 终端文件浏览器，纯 zsh 函数实现，PowerShell 版文件管理器的 macOS 移植。

## 介绍

| 按键 | 功能 |
|---|---|
| `↑` / `k` | 上移 |
| `↓` / `j` | 下移 |
| `→` / `l` | 进入文件夹 |
| `←` / `h` / `Backspace` | 返回上级 |
| `Enter` | 用系统默认程序打开文件 |
| `<` / `>` | 上一页 / 下一页（每页 15 项） |
| `c` | 输入/粘贴路径跳转 |
| `d` | 移到废纸篓（需确认） |
| `Shift+D` | 直接移到废纸篓（免确认） |
| `q` | 退出，并将终端目录切换到当前浏览位置 |

附带命令：`o` 在访达打开当前目录，`codep` 编辑 `~/.zshrc`。

## macos安装

进入 `~/.zshrc`并将 `y` 追加进去；

[安装代码](y.mac.sh)


# y for windows
安装方法：
打开powershell，输入 code $profile 打开配置文件，然后贴入下面的 function y ，然后开新的tab 输入 y , enter 即可使用。


[安装代码](y.win.ps1)

