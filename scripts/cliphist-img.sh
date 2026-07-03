#!/bin/bash

TMP_DIR="$HOME/.cache/quickshell/cliphist-imgs"
mkdir -p "$TMP_DIR"

if [[ -z "$1" ]]; then
    cliphist list | while IFS=$'\t' read -r id rest; do
        if [[ "$rest" == *"[[ binary data"* ]]; then
            img_path="$TMP_DIR/$id.png"
            [[ ! -f "$img_path" ]] && cliphist decode <<<"$id"$'\t'"$rest" > "$img_path"
            printf "%s\t%s\000icon\x1f%s\n" "$id" "$rest" "$img_path"
        else
            printf "%s\t%s\n" "$id" "$rest"
        fi
    done
else
    cliphist decode <<<"$1" | wl-copy
fi
