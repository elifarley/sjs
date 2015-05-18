SJS_QDIR=${SJS_QDIR:-~/.sjs}

dir_item_count() {
  test -d "$1" && \
  echo $(( $(\ls -afq "$1" 2>/dev/null | wc -l )  -2 ))
}

add() {
  (( 2 == $# )) || return 1
  local when="$1"; shift
  local label="$1"; shift
  cat > "$SJS_QDIR"/todo/"$when.$label-$RANDOM"
}

run_loop() {
  while true; do
    run_once
    sleep 10
  done
}

run_once() {

local qcount=$(dir_item_count "$SJS_QDIR"/todo) || {
  echo "todo dir not found: '$SJS_QDIR/todo/"; return 1
}

((qcount)) || echo "Waiting for jobs at '$SJS_QDIR/todo/'..."

until qcount=$(dir_item_count "$SJS_QDIR"/todo) && ((qcount > 0)); do sleep 1; done
((qcount)) || { echo "Unexpected qcount: $qcount"; return 1; }

echo "Found $qcount jobs"

local when joblabel

for i in $(\ls -af "$SJS_QDIR"/todo/ | grep -v '^\.' | sort); do

  when="${i%%.*}"; joblabel="${i##*.}"

  test "$(date +'%Y-%m-%d-%H:%M')" \> "$when" || continue

  echo -e "--\n\nProcessing $joblabel @ $when..."

  mv "$SJS_QDIR/todo/$i" "$SJS_QDIR/running/" && \
  time bash "$SJS_QDIR/running/$i" 2>&1 > "$SJS_QDIR/running/$i".out \
  && { echo -e "\nItem $i done!"; mv "$SJS_QDIR/running/$i"* "$SJS_QDIR/done/"; } \
  || { echo -e "\n### ERROR in $i ###"; mv "$SJS_QDIR/running/$i"* "$SJS_QDIR/error/"; }

done

} # run_once

stats() {
  echo "SJS_QDIR: $SJS_QDIR"
  (($#)) || {
    (cd "$SJS_QDIR" && find -type f) | cut -d/ -f2- | sort && \
    return 0
  }

  (cd "$SJS_QDIR" && find -iname "*$1*") | cut -d/ -f2- | sort

}

(($#)) || exit 1

OP="$1"; shift

case "$OP" in
add)
  add "$@"
  ;;
run)
  run_loop "$@"
  ;;
run-once)
  run_once "$@"
  ;;
stats)
  stats "$@"
  ;;
esac
