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

## 卸载

删除 `~/.zshrc` 中 `# >>> y >>>` 到 `# <<< y <<<` 之间的内容，或用安装时生成的 `.zshrc.bak_*` 备份还原。

## macos安装

把安装脚本粘贴到终端执行即可。脚本会自动备份 `~/.zshrc`（备份名为 `.zshrc.bak_时间戳`），并将 `y` 追加进去；重复执行会替换旧版，不会重复追加。

[安装代码](y.mac.sh)：


# y for windows
安装方法：
打开powershell，输入 code $profile 打开配置文件，然后贴入下面的 function y ，然后开新的tab 输入 y , enter 即可使用。


```
function y {
    $currentPath = (Get-Location).Path;
    $selectedIndex = 0;
    $pageSize = 15;
    $filter = "";

    Add-Type -AssemblyName Microsoft.VisualBasic;
    [Console]::CursorVisible = $false;
    Clear-Host;

    try {
        while ($true) {
            $rawItems = @();
            if (Test-Path -LiteralPath $currentPath -PathType Container) {
                try { $rawItems = @(Get-ChildItem -LiteralPath $currentPath -ErrorAction Stop); } catch {}
            }

            if (-not [string]::IsNullOrWhiteSpace($filter)) {
                $items = @($rawItems | Where-Object { $_.Name -like "*$filter*" });
            } else {
                $items = $rawItems;
            }

            $totalCount = $items.Count;
            if ($totalCount -gt 0) {
                if ($selectedIndex -ge $totalCount) { $selectedIndex = $totalCount - 1; }
                if ($selectedIndex -lt 0) { $selectedIndex = 0; }
            } else {
                $selectedIndex = 0;
            }

            $currentPage = [Math]::Floor($selectedIndex / $pageSize);
            $totalPages = if ($totalCount -gt 0) { [Math]::Ceiling($totalCount / $pageSize); } else { 1; }
            $startIndex = $currentPage * $pageSize;
            $endIndex = [Math]::Min($startIndex + $pageSize - 1, $totalCount - 1);

            [Console]::SetCursorPosition(0, 0);
            $winWidth = [Math]::Max(20, [Console]::WindowWidth - 1);

            $filterTag = if (-not [string]::IsNullOrWhiteSpace($filter)) { " [Filter: $filter]" } else { "" };
            $header = " 📂 $currentPath$filterTag [Page $($currentPage + 1)/$totalPages]".PadRight($winWidth);
            Write-Host $header -ForegroundColor Cyan;
            Write-Host ("─" * $winWidth) -ForegroundColor DarkGray;

            if ($totalCount -eq 0) {
                $emptyTip = if (-not [string]::IsNullOrWhiteSpace($filter)) { "  <No matching items>" } else { "  <Empty Directory>" };
                Write-Host $emptyTip.PadRight($winWidth) -ForegroundColor DarkGray;
                for ($k = 1; $k -lt $pageSize; $k++) { Write-Host (" " * $winWidth); }
            } else {
                for ($i = 0; $i -lt $pageSize; $i++) {
                    $actualIndex = $startIndex + $i;
                    if ($actualIndex -le $endIndex) {
                        $item = $items[$actualIndex];
                        $prefix = if ($item.PSIsContainer) { "📁 " } else { "📄 " };
                        $rawStr = " $prefix$($item.Name)";
                        $enc = [System.Text.Encoding]::GetEncoding('GBK');
                        $visualWidth = $enc.GetByteCount($rawStr);
                        $padLen = [Math]::Max(0, $winWidth - $visualWidth);
                        $lineText = $rawStr + (" " * $padLen);

                        if ($actualIndex -eq $selectedIndex) {
                            Write-Host $lineText -BackgroundColor DarkCyan -ForegroundColor White;
                        } else {
                            $fg = if ($item.PSIsContainer) { "Yellow" } else { "White" };
                            Write-Host $lineText -ForegroundColor $fg;
                        }
                    } else {
                        Write-Host (" " * $winWidth);
                    }
                }
            }

            Write-Host ("─" * $winWidth) -ForegroundColor DarkGray;
            $status = " [$($selectedIndex + 1)/$totalCount] [↑↓←→/HJKL]Move [Enter]Start [< >]Page [C]CD [D]Trash [/]Search [Q]Quit";
            Write-Host $status.PadRight($winWidth) -ForegroundColor Green;

            $key = [Console]::ReadKey($true);

            $isUp = $key.Key -eq 'UpArrow' -or $key.KeyChar -eq 'k' -or $key.KeyChar -eq 'K';
            $isDown = $key.Key -eq 'DownArrow' -or $key.KeyChar -eq 'j' -or $key.KeyChar -eq 'J';
            $isLeft = $key.Key -eq 'LeftArrow' -or $key.KeyChar -eq 'h' -or $key.KeyChar -eq 'H';
            $isRight = $key.Key -eq 'RightArrow' -or $key.KeyChar -eq 'l' -or $key.KeyChar -eq 'L';

            if ($isUp) {
                if ($totalCount -gt 0) {
                    $oldPage = [Math]::Floor($selectedIndex / $pageSize);
                    if ($selectedIndex -eq 0) { $selectedIndex = $totalCount - 1; } else { $selectedIndex--; }
                    $newPage = [Math]::Floor($selectedIndex / $pageSize);
                    if ($oldPage -ne $newPage) { Clear-Host; }
                }
            } elseif ($isDown) {
                if ($totalCount -gt 0) {
                    $oldPage = [Math]::Floor($selectedIndex / $pageSize);
                    if ($selectedIndex -eq ($totalCount - 1)) { $selectedIndex = 0; } else { $selectedIndex++; }
                    $newPage = [Math]::Floor($selectedIndex / $pageSize);
                    if ($oldPage -ne $newPage) { Clear-Host; }
                }
            } elseif ($isRight) {
                if ($totalCount -gt 0 -and $items[$selectedIndex].PSIsContainer) {
                    $currentPath = $items[$selectedIndex].FullName;
                    $selectedIndex = 0;
                    $filter = "";
                    Clear-Host;
                }
            } elseif ($isLeft -or $key.Key -eq 'Backspace') {
                $parent = $currentPath | Split-Path -Parent;
                if ($parent) {
                    $childName = Split-Path -Leaf $currentPath;
                    $currentPath = $parent;
                    $filter = "";
                    $parentItems = @(Get-ChildItem -LiteralPath $currentPath -ErrorAction SilentlyContinue);
                    $foundIndex = -1;
                    for ($idx = 0; $idx -lt $parentItems.Count; $idx++) {
                        if ($parentItems[$idx].Name -eq $childName) { $foundIndex = $idx; break; }
                    }
                    $selectedIndex = if ($foundIndex -ge 0) { $foundIndex; } else { 0; };
                    Clear-Host;
                }
            }

            switch ($key.Key) {
                'Enter' {
                    if ($totalCount -gt 0) {
                        $selectedItem = $items[$selectedIndex];
                        Invoke-Item -LiteralPath $selectedItem.FullName -ErrorAction SilentlyContinue;
                    }
                }
                'C' {
                    [Console]::CursorVisible = $true;
                    Write-Host "`n";
                    $rawInput = Read-Host " Enter/Paste Directory Path";
                    [Console]::CursorVisible = $false;

                    if (-not [string]::IsNullOrWhiteSpace($rawInput)) {
                        $targetPath =$rawInput.Trim().Trim('"').Trim("'");
                        if (Test-Path -LiteralPath $targetPath -PathType Container) {
                            $currentPath = (Get-Item -LiteralPath$targetPath).FullName;
                            $selectedIndex = 0;
                            $filter = "";
                        } else {
                            Write-Host " Directory not found! Press any key to continue..." -ForegroundColor Red;
                            $null = [Console]::ReadKey($true);
                        }
                    }
                    Clear-Host;
                }
                'D' {
                    if ($totalCount -gt 0) {$selectedItem = $items[$selectedIndex];
                        $skipConfirm =$key.Modifiers.HasFlag([ConsoleModifiers]::Shift);
                        $shouldDelete =$false;

                        if ($skipConfirm) {
                            $shouldDelete =$true;
                        } else {
                            [Console]::CursorVisible = $true;
                            Write-Host "`n";
                            $confirm = Read-Host " Move [$($selectedItem.Name)] to Recycle Bin? (Y/n)";
                            [Console]::CursorVisible = $false;
                            if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm -eq 'y' -or $confirm -eq 'Y') {
                                $shouldDelete = $true;
                            }
                        }

                        if ($shouldDelete) {
                            try {
                                if ($selectedItem.PSIsContainer) {
                                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($selectedItem.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin');
                                } else {
                                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($selectedItem.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin');
                                }
                            } catch {
                                Write-Host " Delete failed: $_" -ForegroundColor Red;
                                $null = [Console]::ReadKey($true);
                            }
                        }
                        Clear-Host;
                    }
                }
                'Q' {
                    Set-Location -LiteralPath $currentPath;
                    Clear-Host;
                    Write-Host "Switched working directory to: $currentPath" -ForegroundColor Cyan;
                    return;
                }
                Default {
                    if ($key.KeyChar -eq '/') {
                        [Console]::CursorVisible = $true;
                        Write-Host "`n";
                        $filterInput = Read-Host " Search / Filter Keyword (Leave empty to clear)";
                        [Console]::CursorVisible = $false;
                        $filter = $filterInput.Trim();$selectedIndex = 0;
                        Clear-Host;
                    } elseif ($key.Key -eq 'Escape') {$filter = "";
                        $selectedIndex = 0;
                        Clear-Host;
                    } elseif ($key.KeyChar -eq ',' -or$key.KeyChar -eq '<') {
                        if ($currentPage -gt 0) {$selectedIndex = ($currentPage - 1) *$pageSize;
                            Clear-Host;
                        }
                    } elseif ($key.KeyChar -eq '.' -or$key.KeyChar -eq '>') {
                        if ($currentPage -lt ($totalPages - 1)) {$selectedIndex = ($currentPage + 1) *$pageSize;
                            Clear-Host;
                        }
                    }
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $true;
    }
}
```

