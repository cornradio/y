emulate -L zsh
setopt EXTENDED_GLOB

_y_bookmarks_file() { echo "$HOME/.y-bookmarks" }

_y_load_bookmarks() {
  local file=$(_y_bookmarks_file)
  [[ -f $file ]] && cat "$file" || echo ""
}

_y_save_bookmarks() {
  local file=$(_y_bookmarks_file)
  printf "%s\n" "$@" > "$file"
}

_y_toggle_bookmark() {
  local path=$1 file=$(_y_bookmarks_file)
  local -a lines=()
  [[ -f $file ]] && mapfile -t lines < "$file"
  
  local found=0
  for line in "${lines[@]}"; do
    [[ "$line" == "$path" ]] && { found=1; break; }
  done
  
  if (( found )); then
    local -a new_lines=()
    for line in "${lines[@]}"; do
      [[ "$line" != "$path" ]] && new_lines+=("$line")
    done
    _y_save_bookmarks "${new_lines[@]}"
    echo "removed"
  else
    _y_save_bookmarks "${lines[@]}" "$path"
    echo "added"
  fi
}

_y_show_bookmarks() {
  local -a bookmarks=()
  local file=$(_y_bookmarks_file)
  [[ -f $file ]] && mapfile -t bookmarks < "$file"
  
  local sel=0 idx total=${#bookmarks[@]} msg="" page=15
  
  while true; do
    printf '\033[H\033[36m🔖 Bookmarks [%d]\033[0m\033[K\n' "$total"
    printf '%*s' $COLUMNS '' | tr ' ' '─'; echo
    
    for (( i=0; i<page; i++ )); do
      if (( i < total )); then
        if (( i == sel )); then
          printf '\033[1;46m 📁 %s\033[0m\033[K\n' "${bookmarks[i]}"
        else
          printf ' 📁 %s\033[K\n' "${bookmarks[i]}"
        fi
      else
        echo ""
      fi
    done
    
    printf '%*s' $COLUMNS '' | tr ' ' '─'; echo
    printf '\033[32m%s\033[0m\033[K' "$msg"
    [[ -z $msg ]] && printf '\033[32m[↑↓]Move [Enter]Go [d]Delete [Esc]Back\033[0m\033[K'
    echo
    
    IFS= read -rs -k 1 key
    case "$key" in
      k) (( sel > 0 )) && sel=$((sel-1)) ;;
      j) (( sel < total-1 )) && sel=$((sel+1)) ;;
      $'\e') IFS= read -rs -k 2 seq
        case "$seq" in
          '[A') (( sel > 0 )) && sel=$((sel-1)) ;;
          '[B') (( sel < total-1 )) && sel=$((sel+1)) ;;
        esac ;;
      $'\n'|$'\r')
        if (( total > 0 )); then
          printf '\033[?25h'; stty "$old_stty" 2>/dev/null
          echo "${bookmarks[sel]}"
          return
        fi ;;
      d|D)
        if (( total > 0 )); then
          local -a new_bm=()
          for (( i=0; i<total; i++ )); do
            (( i != sel )) && new_bm+=("${bookmarks[i]}")
          done
          _y_save_bookmarks "${new_bm[@]}"
          bookmarks=("${new_bm[@]}")
          total=${#bookmarks[@]}
          (( sel >= total )) && sel=$((total-1))
          msg="✓ Deleted"
          clear
        fi ;;
      $'\033') printf '\033[?25h'; stty "$old_stty" 2>/dev/null; return ;; 
    esac
  done
}

y() {
  local dir="$PWD" old_stty key seq item input dest name child filter="" esc msg=""
  local -i sel=0 page=15 total start i idx pages del show_dot=1
  local -a items all
  old_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear
  while true; do
    while [[ $dir == *'//'* ]]; do dir=${dir//\/\//\/}; done
    [[ $dir != / ]] && dir=${dir%/}
    if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi
    if [[ -n $filter ]]; then
      all=( "${items[@]}" ); items=()
      for item in "${all[@]}"; do [[ ${${item:t}:l} == *${filter:l}* ]] && items+=( "$item" ); done
    fi
    total=${#items}
    (( total == 0 )) && sel=0 || { (( sel >= total )) && sel=$((total-1)); (( sel < 0 )) && sel=0; }
    pages=$(( total ? (total + page - 1) / page : 1 )); start=$(( sel / page * page ))
    printf '\033[H\033[36m📂 %s%s%s [Page %d/%d]\033[0m\033[K\n' "$dir" "${filter:+ 🔍/$filter}" $(( sel / page + 1 )) $pages
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
    if [[ -n $msg ]]; then
      printf '\033[32m%s\033[0m\033[K\n' "$msg"
      msg=""
    else
      printf '\033[32m[%d/%d] [hjkl/↑↓←→]Move [Enter]Open []Page [v/V]Code [/]Search [.]Dot [C]CD [R]Rename [d/D]Trash [g]Bookmarks [Q]Quit\033[0m\033[K\n' $((sel+1)) $total
    fi
    IFS= read -rs -k 1 key
    case "$key" in
      $'\e')
        IFS= read -rs -k 2 seq
        case "$seq" in
          '[A') if (( sel > 0 )); then sel=$((sel-1)); elif (( total )); then sel=$((total-1)); fi ;;
          '[B') if (( sel < total-1 )); then sel=$((sel+1)); else sel=0; fi ;;
          '[C') if (( total )); then item=${items[$((sel+1))]}; [[ -d $item ]] && { child=${item:t}; dir=$item; sel=0; filter=""; if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi; for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear; } fi ;;
          '[D') child=${dir:t}; dir=${dir:h}; sel=0; filter=""; if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi; for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
        esac ;;
      k|K) if (( sel > 0 )); then sel=$((sel-1)); elif (( total )); then sel=$((total-1)); fi ;;
      j|J) if (( sel < total-1 )); then sel=$((sel+1)); else sel=0; fi ;;
      l|L) if (( total )); then item=${items[$((sel+1))]}; [[ -d $item ]] && { child=${item:t}; dir=$item; sel=0; filter=""; if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi; for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear; } fi ;;
      h) child=${dir:t}; dir=${dir:h}; sel=0; filter=""; if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi; for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
      '.') show_dot=$(( 1 - show_dot )); sel=0; clear ;;
      '/')
        printf '\033[?25h\n'; stty "$old_stty" 2>/dev/null
        read "input?/ Search filename (empty to clear): "
        filter=$input; sel=0
        stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear ;;
      r|R)
        if (( total )); then
          item=${items[$((sel+1))]}
          printf '\033[?25h\n'; stty "$old_stty" 2>/dev/null
          read "input?Rename [${item:t}] to: "
          if [[ -n $input ]]; then
            input=${input//\//}; dest="$dir/$input"
            if [[ -e $dest ]]; then
              printf '\033[31mName already exists! Press any key...\033[0m'
              stty -echo -icanon 2>/dev/null; IFS= read -rs -k 1
            elif ! mv "$item" "$dest" 2>/tmp/.y_err; then
              printf '\033[31mRename failed: %s\nPress any key...\033[0m' "$(</tmp/.y_err)"
              stty -echo -icanon 2>/dev/null; IFS= read -rs -k 1
            else
              child=$input
              if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi
              if [[ -n $filter ]]; then
                all=( "${items[@]}" ); items=()
                for item in "${all[@]}"; do [[ ${${item:t}:l} == *${filter:l}* ]] && items+=( "$item" ); done
              fi
              for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done
            fi
          fi
          stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear
        fi ;;
      $'\n'|$'\r') (( total )) && open "${items[$((sel+1))]}" ;;
      v) (( total )) && code "${items[$((sel+1))]}" ;;
      V)
        if (( total )); then
          printf '\033[?25h'; stty "$old_stty" 2>/dev/null
          vim "${items[$((sel+1))]}"
          stty -echo -icanon 2>/dev/null; printf '\033[?25l'; clear
        fi ;;
      $'\x7f'|$'\b') child=${dir:t}; dir=${dir:h}; sel=0; filter=""; if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi; for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
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
      g|G)
        if [[ $key == G ]]; then
          result=$(_y_show_bookmarks)
          if [[ -n $result ]]; then
            [[ -d $result ]] && dir="$result" && sel=0 && filter="" && clear
          else
            clear
          fi
        else
          if _y_toggle_bookmark "$dir" | grep -q added; then
            msg="✓ Bookmarked: $dir"
          else
            msg="✗ Removed bookmark: $dir"
          fi
          clear
        fi ;;
      '['|'【') (( start > 0 )) && sel=$((start-page)) && clear ;;
      ']'|'】') (( start + page < total )) && sel=$((start+page)) && clear ;;
    esac
  done
  [[ -n $old_stty ]] && stty "$old_stty" 2>/dev/null
  printf '\033[?25h'; clear; cd "$dir" && echo "Switched working directory to: $dir"
}