# y
零依赖的终端文件浏览器(目前支持 macos、windows）
安装后新开终端，或直接输入 `y` 启动。

macos 截图

<img width="600" height="" alt="image" src="https://github.com/user-attachments/assets/3cc74f96-1fbb-44e3-9ce4-e163200807e9" />

win 截图

<img width="600" height="" alt="image" src="https://github.com/user-attachments/assets/562093e5-9fca-47a4-b66c-fccdcdcceeaf" />


# y （formacos）

一个零依赖的 macOS 终端文件浏览器，纯 zsh 函数实现，PowerShell 版文件管理器的 macOS 移植。

## 安装

把安装脚本粘贴到终端执行即可。脚本会自动备份 `~/.zshrc`（备份名为 `.zshrc.bak_时间戳`），并将 `y` 追加进去；重复执行会替换旧版，不会重复追加。

## 使用

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

安装代码：

```
PROFILE_FILE="$HOME/.zshrc"
if [[ -f "$PROFILE_FILE" ]]; then
  b="$PROFILE_FILE.bak_$(date +%Y%m%d_%H%M%S)"
  cp "$PROFILE_FILE" "$b" && echo "✅ [成功] 已自动备份旧 .zshrc 至:"$'\n'" 📄 $b"$'\n'
else
  echo "ℹ️  [提示] 未找到旧 .zshrc，将直接创建新配置文件。"$'\n'; touch "$PROFILE_FILE"
fi

grep -q '# >>> y >>>' "$PROFILE_FILE" && perl -0pi -e 's/\n?# >>> y >>>.*?# <<< y <<<\n?/\n/s' "$PROFILE_FILE" && echo "🔄 已删除旧版 y，准备写入新版"
grep -q 'my-yazi for macOS' "$PROFILE_FILE" && perl -0pi -e 's/\n# ===== my-yazi for macOS =====.*//s' "$PROFILE_FILE"

cat >> "$PROFILE_FILE" << 'EOF'
# >>> y >>>
unalias o y codep 2>/dev/null
o() { open .; }
codep() { if command -v code >/dev/null 2>&1; then code ~/.zshrc; else vim ~/.zshrc; fi; }
y() {
  local dir="$PWD" old_stty key seq item input dest name child filter="" esc
  local -i sel=0 page=15 total start i idx pages del
  local -a items all
  old_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear
  while true; do
    while [[ $dir == *'//'* ]]; do dir=${dir//\/\//\/}; done
    [[ $dir != / ]] && dir=${dir%/}
    items=( "$dir"/*(N) )
    if [[ -n $filter ]]; then
      all=( "${items[@]}" ); items=()
      for item in "${all[@]}"; do [[ ${${item:t}:l} == *${filter:l}* ]] && items+=( "$item" ); done
    fi
    total=${#items}
    (( total == 0 )) && sel=0 || { (( sel >= total )) && sel=$((total-1)); (( sel < 0 )) && sel=0; }
    pages=$(( total ? (total + page - 1) / page : 1 )); start=$(( sel / page * page ))
    printf '\033[H\033[36m📂 %s%s [Page %d/%d]\033[0m\033[K\n' "$dir" "${filter:+ 🔍/$filter}" $(( sel / page + 1 )) $pages
    printf '%*s' $COLUMNS '' | tr ' ' '─'; echo
    if (( total == 0 )); then
      [[ -n $filter ]] && echo '  <No Match>' || echo '  <Empty Directory>'
      for (( i=1; i<page; i++ )); do echo; done
    else
      for (( i=0; i<page; i++ )); do
        idx=$(( start + i ))
        if (( idx < total )); then
          item=${items[$((idx+1))]}; name=${item:t}
          (( ${#name} > COLUMNS - 4 )) && name="${name[1,$((COLUMNS-7))]}..."
          if (( idx == sel )); then printf '\033[1;43;30m %s %s\033[0m\033[K\n' "$([[ -d $item ]] && echo 📁 || echo 📄)" "$name"
          elif [[ -d $item ]]; then printf '\033[33m 📁 %s\033[0m\033[K\n' "$name"
          else printf ' 📄 %s\033[K\n' "$name"; fi
        else echo; fi
      done
    fi
    printf '%*s' $COLUMNS '' | tr ' ' '─'; echo
    printf '\033[32m[%d/%d] [hjkl/↑↓←→]Move [Enter]Open [<>]Page [/]Search [C]CD [d]Trash [Q]Quit\033[0m\033[K' $((sel+1)) $total
    IFS= read -rs -k 1 key
    case "$key" in
      $'\e')
        IFS= read -rs -k 2 seq
        case "$seq" in
          '[A') if (( sel > 0 )); then sel=$((sel-1)); elif (( total )); then sel=$((total-1)); fi ;;
          '[B') if (( sel < total-1 )); then sel=$((sel+1)); else sel=0; fi ;;
          '[C') item=${items[$((sel+1))]}; [[ -d $item ]] && { dir=$item; sel=0; filter=""; clear; } ;;
          '[D') child=${dir:t}; dir=${dir:h}; sel=0; filter=""; items=( "$dir"/*(N) ); for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
        esac ;;
      k) if (( sel > 0 )); then sel=$((sel-1)); elif (( total )); then sel=$((total-1)); fi ;;
      j) if (( sel < total-1 )); then sel=$((sel+1)); else sel=0; fi ;;
      l) item=${items[$((sel+1))]}; [[ -d $item ]] && { dir=$item; sel=0; filter=""; clear; } ;;
      h) child=${dir:t}; dir=${dir:h}; sel=0; filter=""; items=( "$dir"/*(N) ); for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
      '/')
        printf '\033[?25h\n'; stty "$old_stty" 2>/dev/null
        read "input?/ Search filename (empty to clear): "
        filter=$input; sel=0
        stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear ;;
      $'\n'|$'\r') (( total )) && open "${items[$((sel+1))]}" ;;
      $'\x7f'|$'\b') child=${dir:t}; dir=${dir:h}; sel=0; filter=""; items=( "$dir"/*(N) ); for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
      q|Q) break ;;
      c|C)
        printf '\033[?25h\n'; stty "$old_stty" 2>/dev/null
        read "input?Enter/Paste Directory Path: "; input=${input/#\~/$HOME}; input=${input//\"/}
        [[ -d $input ]] && dir=$(cd "$input" && pwd) && sel=0 && filter="" || { echo 'Directory not found!'; sleep 1; }
        stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear ;;
      d|D)
        if (( total )); then
          item=${items[$((sel+1))]}; del=0
          if [[ $key == D ]]; then
            del=1
          else
            printf '\033[?25h\n'; stty "$old_stty" 2>/dev/null
            read "input?Move [${item:t}] to Trash? (Y/n) "
            [[ -z $input || $input == [yY] ]] && del=1
            stty -echo -icanon 2>/dev/null; printf '\033[?25l'
          fi
          if (( del )); then
            esc=${item//\\/\\\\}; esc=${esc//\"/\\\"}
            osascript -e "tell application \"Finder\" to delete POSIX file \"$esc\"" >/dev/null 2>&1 || {
              mkdir -p "$HOME/.Trash"
              dest="$HOME/.Trash/${item:t}"; [[ -e $dest ]] && dest="$dest.$(date +%H%M%S)"
              mv "$item" "$dest"
            }
          fi
          clear
        fi ;;
      ','|'<') (( start > 0 )) && sel=$((start-page)) && clear ;;
      '.'|'>') (( start + page < total )) && sel=$((start+page)) && clear ;;
    esac
  done
  [[ -n $old_stty ]] && stty "$old_stty" 2>/dev/null
  printf '\033[?25h'; clear; cd "$dir" && echo "Switched working directory to: $dir"
}
# <<< y <<<
EOF

unalias o y codep 2>/dev/null
eval "$(sed -n '/^# >>> y >>>$/,/^# <<< y <<<$/p' "$PROFILE_FILE")"
echo "🎉 y 已安装/更新完成！输入 y 启动，o 打开当前文件夹，codep 编辑 ~/.zshrc"
```

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

