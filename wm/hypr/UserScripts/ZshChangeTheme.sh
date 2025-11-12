#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for Oh my ZSH theme ( CTRL SHIFT O)

# preview of theme can be view here: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# after choosing theme, TTY need to be closed and re-open

# Variables
iDIR="$HOME/.config/swaync/images"
rofi_theme="$HOME/.config/rofi/config-zsh-theme.rasi"

if [ -n "$(grep -i nixos < /etc/os-release)" ]; then
  notify-send -i "$iDIR/note.png" "NOT Supported" "Sorry NixOS does not support this KooL feature"
  exit 1
fi

file_extension=".zsh-theme"
themes_dirs=(
    "$HOME/.oh-my-zsh/themes"
    "/usr/share/oh-my-zsh/themes"
    "$HOME/.config/oh-my-zsh/themes"
)

declare -A seen_themes
themes_array=()

for dir in "${themes_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
        while IFS= read -r theme_file; do
            rel_path="${theme_file#${dir}/}"
            rel_path="${rel_path%$file_extension}"
            rel_path="${rel_path#./}"
        [[ -z "$rel_path" ]] && continue
        if [[ -z ${seen_themes["$rel_path"]} ]]; then
            themes_array+=("$rel_path")
            seen_themes["$rel_path"]=1
        fi
    done < <(find -L "$dir" -type f -name "*$file_extension" -print)
done

IFS=$'\n' themes_array=($(sort <<<"${themes_array[*]}"))
unset IFS

# Add "Random" option to the beginning of the array
themes_array=("Random" "${themes_array[@]}")

rofi_command="rofi -i -dmenu -config $rofi_theme"

menu() {
    for theme in "${themes_array[@]}"; do
        echo "$theme"
    done

    if ((${#themes_array[@]})); then
        mapfile -t themes_array < <(printf '%s
    choice=$(menu | ${rofi_command})
    fi

    # if nothing selected, script won't change anything
    if [ -z "$choice" ]; then
        exit 0
    fi

    zsh_path="$HOME/.zshrc"
    var_name="ZSH_THEME"

    if [[ "$choice" == "Random" ]]; then
        # Pick a random theme from the original themes_array (excluding "Random")
        random_theme=${themes_array[$((RANDOM % (${#themes_array[@]} - 1) + 1))]}
        theme_to_set="$random_theme"
        notify-send -i "$iDIR/ja.png" "Random theme:" "selected: $random_theme"
    else
        # Set theme to the selected choice
        theme_to_set="$choice"
        notify-send -i "$iDIR/ja.png" "Theme selected:" "$choice"
    fi

    if [ -f "$zsh_path" ]; then
        sed -i "s/^$var_name=.*/$var_name=\"$theme_to_set\"/" "$zsh_path"
        notify-send -i "$iDIR/ja.png" "OMZ theme" "applied. restart your terminal"
    else
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "~.zshrc file not found!"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
