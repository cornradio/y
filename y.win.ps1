function y {

    function Get-YBookmarkFile { return Join-Path $HOME ".y-bookmarks.json"; }

    function Get-YBookmarks {
        $file = Get-YBookmarkFile;
        if (-not (Test-Path -LiteralPath $file)) { return @(); }
        $data = Get-Content -Raw -LiteralPath $file -Encoding UTF8 | ConvertFrom-Json;
        return @($data | Where-Object { $_ });
    }

    function Save-YBookmarks([string[]]$list) {
        $json = ConvertTo-Json -InputObject @($list);
        $utf8 = New-Object System.Text.UTF8Encoding $false;
        [System.IO.File]::WriteAllText((Get-YBookmarkFile), $json, $utf8);
    }

    function Get-YKey([string]$path) {
        return $path.TrimEnd('\').ToLowerInvariant();
    }

    function Switch-YBookmark([string]$path) {
        $key = Get-YKey $path;
        $list = @(Get-YBookmarks);
        $kept = @($list | Where-Object { (Get-YKey $_) -ne $key });
        if ($kept.Count -lt $list.Count) {
            Save-YBookmarks $kept;
            return "removed";
        }
        Save-YBookmarks (@($list) + $path);
        return "added";
    }

    function Show-YBookmarks {
        $pageSize = 15;
        $idx = 0;
        $msg = "";
        Clear-Host;
        while ($true) {
            $list = @(Get-YBookmarks);
            if ($list.Count -eq 0) { $idx = 0; } elseif ($idx -ge $list.Count) { $idx = $list.Count - 1; }
            $winWidth = [Math]::Max(20, [Console]::WindowWidth - 1);

            [Console]::SetCursorPosition(0, 0);
            Write-Host (" 🔖 Bookmarks [$($list.Count)]".PadRight($winWidth)) -ForegroundColor Cyan;
            Write-Host ("─" * $winWidth) -ForegroundColor DarkGray;

            $startIndex = [Math]::Floor($idx / $pageSize) * $pageSize;
            for ($i = 0; $i -lt $pageSize; $i++) {
                $n = $startIndex + $i;
                if ($n -ge $list.Count) { Write-Host (" " * $winWidth); continue; }
                $p = $list[$n];
                $exists = Test-Path -LiteralPath $p -PathType Container;
                $text = " 📁 $p$(if (-not $exists) { '  (missing)' })".PadRight($winWidth);
                if ($n -eq $idx) {
                    Write-Host $text -BackgroundColor DarkCyan -ForegroundColor White;
                } else {
                    $fg = if ($exists) { "Yellow" } else { "DarkGray" };
                    Write-Host $text -ForegroundColor $fg;
                }
            }

            Write-Host ("─" * $winWidth) -ForegroundColor DarkGray;
            $status = if ($msg) { $msg } else { " [↑↓]Move [Enter]Go [D]Remove [Esc]Back" };
            Write-Host $status.PadRight($winWidth) -ForegroundColor Green;
            $msg = "";

            $k = [Console]::ReadKey($true);
            if ($k.Key -eq 'Escape') { return $null; }
            if ($k.Key -eq 'UpArrow' -or $k.KeyChar -eq 'k' -or $k.KeyChar -eq 'K') {
                if ($list.Count -gt 0) { $idx = if ($idx -eq 0) { $list.Count - 1 } else { $idx - 1 }; }
                continue;
            }
            if ($k.Key -eq 'DownArrow' -or $k.KeyChar -eq 'j' -or $k.KeyChar -eq 'J') {
                if ($list.Count -gt 0) { $idx = if ($idx -eq $list.Count - 1) { 0 } else { $idx + 1 }; }
                continue;
            }
            if ($k.Key -eq 'Enter' -and $list.Count -gt 0) {
                $p = $list[$idx];
                if (Test-Path -LiteralPath $p -PathType Container) { return $p; }
                $msg = " Folder not found: $p";
                continue;
            }
            if ($k.Key -eq 'D' -and $list.Count -gt 0) {
                $removeKey = Get-YKey $list[$idx];
                $removed = $list[$idx];
                Save-YBookmarks @($list | Where-Object { (Get-YKey $_) -ne $removeKey });
                $msg = " Removed bookmark: $removed";
            }
        }
    }

    $currentPath = (Get-Location).Path;
    $selectedIndex = 0;
    $pageSize = 15;
    $filter = "";
    $yMsg = "";

    Add-Type -AssemblyName Microsoft.VisualBasic;
    [Console]::CursorVisible = $false;
    Clear-Host;

    try {
        while ($true) {
            $folderTitle = Split-Path -Leaf $currentPath;
            if ([string]::IsNullOrWhiteSpace($folderTitle)) { $folderTitle = $currentPath; }
            $Host.UI.RawUI.WindowTitle = $folderTitle;

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
            $status = if ($yMsg) { $yMsg } else { " [$($selectedIndex + 1)/$totalCount] [↑↓←→/hjkl]Move [Enter]Start [V]Code []Page [C]CD [R]Rename [D]Trash [G]bookmark [/]Search [Q]Quit" };
            $yMsg = "";
            Write-Host $status.PadRight($winWidth) -ForegroundColor Green;

            $key = [Console]::ReadKey($true);

            $isUp = $key.Key -eq 'UpArrow' -or $key.KeyChar -eq 'k' -or $key.KeyChar -eq 'K';
            $isDown = $key.Key -eq 'DownArrow' -or $key.KeyChar -eq 'j' -or $key.KeyChar -eq 'J';
            $isLeft = $key.Key -eq 'LeftArrow' -or $key.KeyChar -eq 'h';
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
                        try {
                            if ($key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) {
                                Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList "`"$($selectedItem.FullName)`"" -ErrorAction Stop;
                            } else {
                                Invoke-Item -LiteralPath $selectedItem.FullName -ErrorAction Stop;
                            }
                        } catch {
                            Write-Host " Open failed: $_`n Press any key to continue..." -ForegroundColor Red;
                            $null = [Console]::ReadKey($true);
                            Clear-Host;
                        }
                    }
                }
                'V' {
                    if ($totalCount -gt 0) {
                        $selectedItem = $items[$selectedIndex];
                        try {
                            if ($key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) {
                                & vim $selectedItem.FullName;
                            } else {
                                & code $selectedItem.FullName;
                            }
                        } catch {
                            $editor = if ($key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) { "Vim" } else { "VS Code" };
                            Write-Host " Open in $editor failed: $_`n Press any key to continue..." -ForegroundColor Red;
                            $null = [Console]::ReadKey($true);
                            Clear-Host;
                        }
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
                            $currentPath = (Get-Item -LiteralPath $targetPath).FullName;
                            $selectedIndex = 0;
                            $filter = "";
                        } else {
                            Write-Host " Directory not found! Press any key to continue..." -ForegroundColor Red;
                            $null = [Console]::ReadKey($true);
                        }
                    }
                    Clear-Host;
                }
                'R' {
                    if ($totalCount -gt 0) {
                        $selectedItem = $items[$selectedIndex];
                        [Console]::CursorVisible = $true;
                        Write-Host "`n";
                        try {
                            $newName = Read-Host " Rename [$($selectedItem.Name)] to (Leave empty to cancel)";
                        } finally {
                            [Console]::CursorVisible = $false;
                        }

                        if (-not [string]::IsNullOrWhiteSpace($newName)) {
                            try {
                                if ($newName -eq '.' -or $newName -eq '..' -or
                                    $newName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
                                    throw "Enter a name only, without a directory path or invalid characters.";
                                }
                                if ($newName -cne $selectedItem.Name) {
                                    Rename-Item -LiteralPath $selectedItem.FullName -NewName $newName -ErrorAction Stop;
                                }
                            } catch {
                                Write-Host " Rename failed: $_`n Press any key to continue..." -ForegroundColor Red;
                                $null = [Console]::ReadKey($true);
                            }
                        }
                        Clear-Host;
                    }
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
                'G' {
                    if ($key.Modifiers.HasFlag([ConsoleModifiers]::Shift)) {
                        $addKey = Get-YKey $currentPath;
                        $already = @(Get-YBookmarks | Where-Object { (Get-YKey $_) -eq $addKey }).Count -gt 0;
                        if ($already) {
                            $yMsg = " Already bookmarked: $currentPath";
                        } else {
                            Save-YBookmarks (@(Get-YBookmarks) + $currentPath);
                            $yMsg = " Bookmarked: $currentPath";
                        }
                    } else {
                        $picked = Show-YBookmarks;
                        Clear-Host;
                        if ($picked) {
                            $currentPath = $picked;
                            $selectedIndex = 0;
                            $filter = "";
                        }
                    }
                }
                'H' {
                    if ((Switch-YBookmark $currentPath) -eq "added") {
                        $yMsg = " Bookmarked: $currentPath";
                    } else {
                        $yMsg = " Removed bookmark: $currentPath";
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
                    } elseif ($key.KeyChar -eq '[' -or $key.KeyChar -eq '【') {
                        if ($currentPage -gt 0) {$selectedIndex = ($currentPage - 1) *$pageSize;
                            Clear-Host;
                        }
                    } elseif ($key.KeyChar -eq ']' -or $key.KeyChar -eq '】') {
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