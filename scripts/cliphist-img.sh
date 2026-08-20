#!/bin/bash

TMP_DIR="$HOME/.cache/chillpill-shell/cliphist-imgs"
mkdir -p "$TMP_DIR"

if [[ "$1" == "delete" && -n "$2" && -n "$3" ]]; then
    id=$2
    cache_img="$TMP_DIR/$id.png"

    # delete the item now, works for non-image item too
    cliphist list | grep -a "^${id}"$'\t' | cliphist delete

    ch_exitcode=$?

    # deleting img cache source file depends on the flag bool
    [[ "$3" == true ]] && [[ $ch_exitcode == 0 ]] && [[ -f "$cache_img" ]] && rm "$cache_img"

elif [[ -z "$1" ]]; then
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
