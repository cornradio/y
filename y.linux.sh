# >>>y

_y_trash() {
  local f=$1 base dest trash now
  if command -v gio >/dev/null 2>&1; then
    gio trash -- "$f" && return
  fi
  if command -v trash-put >/dev/null 2>&1; then
    trash-put -- "$f" && return
  fi
  trash="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
  mkdir -p "$trash/files" "$trash/info" || return 1
  base=$(basename -- "$f")
  dest="$trash/files/$base"
  [[ -e $dest ]] && dest="$trash/files/${base}.$(date +%Y%m%d_%H%M%S)"
  now=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
  printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' "$f" "$now" > "$trash/info/$(basename -- "$dest").trashinfo"
  mv -- "$f" "$dest"
}

_y_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Uses caller's `items` and `show_dot` (bash dynamic scope).
_y_list() {
  local d=$1
  local -a raw=()
  local p base
  if (( show_dot )); then
    shopt -s nullglob dotglob
  else
    shopt -s nullglob
    shopt -u dotglob 2>/dev/null || true
  fi
  raw=( "$d"/* )
  shopt -u nullglob
  shopt -u dotglob 2>/dev/null || true
  items=()
  for p in "${raw[@]}"; do
    base=${p##*/}
    [[ $base == . || $base == .. ]] && continue
    items+=( "$p" )
  done
}


y() {
  local dir="$PWD" old_stty key seq item input dest name child filter=""
  local -i sel=0 page=15 total start i idx pages del show_dot=1
  local -a items all
  local cols
  old_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon 2>/dev/null
  printf '\033[?25l'
  clear
  while true; do
    while [[ $dir == *'//'* ]]; do dir=${dir//\/\//\/}; done
    [[ $dir != / ]] && dir=${dir%/}
    _y_list "$dir"
    if [[ -n $filter ]]; then
      all=( "${items[@]}" )
      items=()
      for item in "${all[@]}"; do
        name=${item##*/}
        [[ $(_y_lower "$name") == *"$(_y_lower "$filter")"* ]] && items+=( "$item" )
      done
    fi
    total=${#items[@]}
    (( total == 0 )) && sel=0 || { (( sel >= total )) && sel=$((total - 1)); (( sel < 0 )) && sel=0; }
    pages=$(( total ? (total + page - 1) / page : 1 ))
    start=$(( sel / page * page ))
    cols=${COLUMNS:-80}
    printf '\033[H\033[36m[DIR] %s%s [Page %d/%d]\033[0m\033[K\n' \
      "$dir" "${filter:+ /$filter}" $(( sel / page + 1 )) $pages
    printf '%*s\n' "$cols" '' | tr ' ' '-'
    if (( total == 0 )); then
      [[ -n $filter ]] && echo '  <No Match>' || echo '  <Empty Directory>'
      for (( i = 1; i < page; i++ )); do echo; done
    else
      for (( i = 0; i < page; i++ )); do
        idx=$(( start + i ))
        if (( idx < total )); then
          item=${items[idx]}
          name=${item##*/}
          if (( ${#name} > cols - 4 )); then
            name="${name:0:$((cols - 7))}..."
          fi
          if (( idx == sel )); then
            if [[ -d $item ]]; then
              printf '\033[1;43;30m 📁 %s\033[0m\033[K\n' "$name"
            else
              printf '\033[1;43;30m 📄 %s\033[0m\033[K\n' "$name"
            fi
          elif [[ -d $item ]]; then
            printf '\033[33m 📁 %s\033[0m\033[K\n' "$name"
          else
            printf ' 📄 %s\033[K\n' "$name"
          fi
        else
          echo
        fi
      done
    fi
    printf '%*s\n' "$cols" '' | tr ' ' '-'
    printf '\033[32m[%d/%d] [hjkl]Move [Enter]Open [<>]Page [/]Search [.]Dot [C]CD [R]Rename [v]vim [d]Trash [Q]Quit\033[0m\033[K' \
      $((sel + 1)) $total
    # bash: -n1 one char; zsh users sourcing this also hit bash if script is bash — keep bash API
    IFS= read -rsn1 key || true
    case "$key" in
      $'\e')
        IFS= read -rsn2 seq || true
        case "$seq" in
          '[A') if (( sel > 0 )); then sel=$((sel - 1)); elif (( total )); then sel=$((total - 1)); fi ;;
          '[B') if (( sel < total - 1 )); then sel=$((sel + 1)); else sel=0; fi ;;
          '[C')
            item=${items[sel]}
            [[ -d $item ]] && { dir=$item; sel=0; filter=""; clear; }
            ;;
          '[D')
            child=${dir##*/}
            dir=$(dirname -- "$dir")
            sel=0; filter=""
            _y_list "$dir"
            for (( idx = 0; idx < ${#items[@]}; idx++ )); do
              [[ ${items[idx]##*/} == "$child" ]] && { sel=$idx; break; }
            done
            clear
            ;;
        esac
        ;;
      k) if (( sel > 0 )); then sel=$((sel - 1)); elif (( total )); then sel=$((total - 1)); fi ;;
      j) if (( sel < total - 1 )); then sel=$((sel + 1)); else sel=0; fi ;;
      l)
        item=${items[sel]}
        [[ -d $item ]] && { dir=$item; sel=0; filter=""; clear; }
        ;;
      h)
        child=${dir##*/}
        dir=$(dirname -- "$dir")
        sel=0; filter=""
        _y_list "$dir"
        for (( idx = 0; idx < ${#items[@]}; idx++ )); do
          [[ ${items[idx]##*/} == "$child" ]] && { sel=$idx; break; }
        done
        clear
        ;;
      '.') show_dot=$(( 1 - show_dot )); sel=0; clear ;;
      '/')
        printf '\033[?25h\n'
        stty "$old_stty" 2>/dev/null
        read -r -p '/ Search filename (empty to clear): ' input
        filter=$input; sel=0
        stty -echo -icanon 2>/dev/null
        printf '\033[?25l'
        clear
        ;;
      r|R)
        if (( total )); then
          item=${items[sel]}
          printf '\033[?25h\n'
          stty "$old_stty" 2>/dev/null
          read -r -p "Rename [${item##*/}] to: " input
          if [[ -n $input ]]; then
            input=${input//\//}
            dest="$dir/$input"
            if [[ -e $dest ]]; then
              printf '\033[31mName already exists! Press any key...\033[0m'
              stty -echo -icanon 2>/dev/null
              IFS= read -rsn1 _
            elif ! mv -- "$item" "$dest" 2>/tmp/.y_err; then
              printf '\033[31mRename failed: %s\nPress any key...\033[0m' "$(</tmp/.y_err)"
              stty -echo -icanon 2>/dev/null
              IFS= read -rsn1 _
            else
              child=$input
              _y_list "$dir"
              if [[ -n $filter ]]; then
                all=( "${items[@]}" ); items=()
                for item in "${all[@]}"; do
                  name=${item##*/}
                  [[ $(_y_lower "$name") == *"$(_y_lower "$filter")"* ]] && items+=( "$item" )
                done
              fi
              for (( idx = 0; idx < ${#items[@]}; idx++ )); do
                [[ ${items[idx]##*/} == "$child" ]] && { sel=$idx; break; }
              done
            fi
          fi
          stty -echo -icanon 2>/dev/null
          printf '\033[?25l'
          clear
        fi
        ;;
      ''|$'\n'|$'\r')
        # Enter: bash read -n1 often gives empty string for Enter
        if (( total )); then
          item=${items[sel]}
          if command -v xdg-open >/dev/null 2>&1 && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
            xdg-open "$item" >/dev/null 2>&1 &
          elif [[ -f $item ]]; then
            printf '\033[?25h'
            stty "$old_stty" 2>/dev/null
            ${PAGER:-less} -- "$item"
            stty -echo -icanon 2>/dev/null
            printf '\033[?25l'
            clear
          elif [[ -d $item ]]; then
            dir=$item; sel=0; filter=""; clear
          fi
        fi
        ;;
      V) (( total )) && command -v code >/dev/null && code "${items[sel]}" ;;
      v)
        if (( total )); then
          printf '\033[?25h'
          stty "$old_stty" 2>/dev/null
          ${EDITOR:-vim} "${items[sel]}"
          stty -echo -icanon 2>/dev/null
          printf '\033[?25l'
          clear
        fi
        ;;
      $'\x7f'|$'\b')
        child=${dir##*/}
        dir=$(dirname -- "$dir")
        sel=0; filter=""
        _y_list "$dir"
        for (( idx = 0; idx < ${#items[@]}; idx++ )); do
          [[ ${items[idx]##*/} == "$child" ]] && { sel=$idx; break; }
        done
        clear
        ;;
      q|Q) break ;;
      c|C)
        printf '\033[?25h\n'
        stty "$old_stty" 2>/dev/null
        read -r -p 'Enter/Paste Directory Path: ' input
        input=${input/#\~/$HOME}
        input=${input//\"/}
        if [[ -d $input ]]; then
          dir=$(cd "$input" && pwd)
          sel=0; filter=""
        else
          echo 'Directory not found!'; sleep 1
        fi
        stty -echo -icanon 2>/dev/null
        printf '\033[?25l'
        clear
        ;;
      d|D)
        if (( total )); then
          item=${items[sel]}; del=0
          if [[ $key == D ]]; then
            del=1
          else
            printf '\033[?25h\n'
            stty "$old_stty" 2>/dev/null
            read -r -p "Move [${item##*/}] to Trash? (Y/n) " input
            [[ -z $input || $input == [yY] ]] && del=1
            stty -echo -icanon 2>/dev/null
            printf '\033[?25l'
          fi
          if (( del )); then
            if ! _y_trash "$item" 2>/tmp/.y_err; then
              printf '\033[31mTrash failed: %s\nPress any key...\033[0m' "$(</tmp/.y_err)"
              stty -echo -icanon 2>/dev/null
              IFS= read -rsn1 _
            fi
          fi
          clear
        fi
        ;;
      ','|'<') (( start > 0 )) && sel=$((start - page)) && clear ;;
      '>') (( start + page < total )) && sel=$((start + page)) && clear ;;
    esac
  done
  [[ -n $old_stty ]] && stty "$old_stty" 2>/dev/null
  printf '\033[?25h'
  clear
  cd "$dir" && echo "Switched working directory to: $dir"
}
