y() {
  local dir="$PWD" old_stty key seq item input dest name child filter="" esc
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
    printf '\033[H\033[36m📂 %s%s%s [Page %d/%d]\033[0m\033[K\n' "$dir" "${filter:+ 🔍/$filter}" "${show_dot:+ ·dot}" $(( sel / page + 1 )) $pages
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
    printf '\033[32m[%d/%d] [hjkl/↑↓←→]Move [Enter]Open [<>]Page [/]Search [.]Dot [C]CD [R]Rename [v]VSCode [d]Trash [Q]Quit\033[0m\033[K' $((sel+1)) $total
    IFS= read -rs -k 1 key
    case "$key" in
      $'\e')
        IFS= read -rs -k 2 seq
        case "$seq" in
          '[A') if (( sel > 0 )); then sel=$((sel-1)); elif (( total )); then sel=$((total-1)); fi ;;
          '[B') if (( sel < total-1 )); then sel=$((sel+1)); else sel=0; fi ;;
          '[C') item=${items[$((sel+1))]}; [[ -d $item ]] && { dir=$item; sel=0; filter=""; clear; } ;;
          '[D') child=${dir:t}; dir=${dir:h}; sel=0; filter=""; if (( show_dot )); then items=( "$dir"/*(ND) ); else items=( "$dir"/*(N) ); fi; for (( idx=1; idx<=${#items}; idx++ )); do [[ ${items[idx]:t} == $child ]] && { sel=$((idx-1)); break; }; done; clear ;;
        esac ;;
      k) if (( sel > 0 )); then sel=$((sel-1)); elif (( total )); then sel=$((total-1)); fi ;;
      j) if (( sel < total-1 )); then sel=$((sel+1)); else sel=0; fi ;;
      l) item=${items[$((sel+1))]}; [[ -d $item ]] && { dir=$item; sel=0; filter=""; clear; } ;;
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
      ','|'<') (( start > 0 )) && sel=$((start-page)) && clear ;;
      '>') (( start + page < total )) && sel=$((start+page)) && clear ;;
    esac
  done
  [[ -n $old_stty ]] && stty "$old_stty" 2>/dev/null
  printf '\033[?25h'; clear; cd "$dir" && echo "Switched working directory to: $dir"
}