SJS_QDIR=${SJS_QDIR:-~/.sjs}
SJS_DATE_FORMAT='%Y-%m-%d.%H:%M'

# TimeStamp in Decimal
millistamp() { local n=$(date +%s%N); echo "${n%??????}" ;}
# TimeStamp in Hex
millistamp_hex() { printf '%x\n' $(millistamp) ;}

# Disable file globbing; coalesce inner whitespace;
# trim leading and trailing whitespace
trim() { (set -f; echo $@) ;}

dir_count() { test -d "$1" && echo $(( $(\ls -afq "$1" 2>/dev/null | wc -l )  -2 )) ;}

_create_dirs() {
  test -d "$SJS_QDIR" || mkdir "$SJS_QDIR"
  local p
  for d in todo running done error trash; do p="$SJS_QDIR"/$d; test -d "$p" || mkdir "$p"; done
}

# Examples:
# add 2015-06-02 18:08 3 hours ago my-label
# add 2015-06-02.18:08 other-label
# add '2015-06-02 18:08'
add() {
  (( $# )) || { echo "Usage: $0 add <WHEN> [LABEL]"; return 1 ;}
  local when=$(trim "${@:1:$#-1}" | tr '.' ' ') label=''
  test "$when" && label=$(trim "${@:$#}") || when="$1"

  when=$( date -d "$when" +"$SJS_DATE_FORMAT" ) || return $?
  _create_dirs || return $?
  local id="$(millistamp_hex)"
  cat > "$SJS_QDIR"/todo/"$when.${label:+$label-}$id" && \
  echo "$id@$when"
}

run_loop() {
  while true; do
    run_once || echo "### run_once FAILED ###"
    sleep 10
  done
}

run_once() {

  _create_dirs || return $?

  local qcount=$(dir_count "$SJS_QDIR"/todo) || {
    echo "todo dir not found: '$SJS_QDIR/todo/"; return 1
  }

  ((qcount)) || echo "Waiting for jobs at '$SJS_QDIR/todo/'..."

  until qcount=$(dir_count "$SJS_QDIR"/todo) && ((qcount > 0)); do sleep 1; done
  ((qcount)) || { echo "Unexpected qcount: $qcount"; return 1; }

  echo "Found $qcount jobs"

  local when joblabel running_path

  for i in $(\ls -af "$SJS_QDIR"/todo/ | grep -v '^\.' | sort); do

    when="${i%.*}"
    test "$(date +"$SJS_DATE_FORMAT")" \> "$when" || continue

    joblabel="${i##*.}"
    echo -e "--\n\nProcessing $joblabel @ $when..."

    running_path="$SJS_QDIR/running/$i"
    mv "$SJS_QDIR/todo/$i" "$(dirname "$running_path")" && \
    ( time bash "$running_path" 2>&1 > "$running_path".out \
      && { echo -e "\nItem $i done!"; mv "$running_path"* "$SJS_QDIR/done/"; } \
      || { echo -e "\n### ERROR in $i ###"; mv "$running_path"* "$SJS_QDIR/error/"; } \
    & )

  done

} # run_once

list() {
  echo "SJS_QDIR: $SJS_QDIR"
  _create_dirs || return $?
  (($#)) || {
    (cd "$SJS_QDIR" && find -type f) | cut -d/ -f2- | sort && \
    return 0
  }

  (cd "$SJS_QDIR" && find -iname "*$1*") | cut -d/ -f2- | sort

}

inspect() {
  (( $# == 1 )) || return 1
  echo "SJS_QDIR: $SJS_QDIR"
  _create_dirs || return $?

  (cd "$SJS_QDIR" && find -iname "*$1*" -exec cat "$SJS_QDIR"/{} \;)

}

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
ls)
  list "$@"
  ;;
cat)
  inspect "$@"
  ;;
*)
  echo $"Usage: $0 {add|run|run-once|ls|cat}"
  exit 1
esac
