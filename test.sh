#!/bin/sh

# vi: et ai ts=4 tw=79

usage() {

    cat << USAGE
Usage: test.sh [-h] [DIRECTORY] [VENDOR] [MAX]

Operands:
---------

    DIRECTORY
        Absolute path to backlight subdirectory in sysfs.

        Defaults to /sys/class/backlight.

    VENDOR
        Symbolic link name under DIRECTORY.

        Defaults to the first symbolic link in DIRECTORY.

    MAX
        Numerical value representing the maximum brightness.

        Defaults to the value in DIRECTORY/VENDOR/max_brightness.

Operands are optional, however, none of them can be skipped if others are
specified.

Example:
--------

    test.sh /sys/class/backlight intel_backlight 96000
USAGE
}

err() {

    printf 'error: %s\n' "$*" >&2
}

# Arguments:
#
#   $1 -- Absolute path to brightness file
#
# Output:
#
#   File content (without trailing newline)
#
# Caveat:
#
#   Its asummed the argument is a readable regular file.
get_brightness() {

    read -r --  brightness < "$1"

    # Using the return builtin command might return wrapped values because it
    # uses the eight least significant bits of its argument to set the value of
    # the special parameter "?".
    printf '%s' "${brightness}"
}

readonly PROGRAM_NAME='backlight_control'

case "$1" in
    (-h | -help | --help)
        usage

        exit 0
    ;;
esac

[ -x "${PROGRAM_NAME}" ] || {

    err "'${PROGRAM_NAME}' executable is missing"

    exit 1
}

[ "$(id -ru)" -ne 0 ] && {

    # Assume group names are conformed of one or more characters from the POSIX
    # portable set.
    for g in $(groups); do

        [ "${g}" = 'video' ] && break

    done || {

        err "user must be in video group to run '${PROGRAM_NAME}'"

        exit 1
    }
}

success=0 fail=0

[ $# -ne 3 ] && {

    readonly SYSFS_CLASS_DIR='/sys/class/backlight'
    # shellcheck disable=2155
    readonly SYSFS_CLASS_DEV="$(find "${SYSFS_CLASS_DIR}" -type l | head -1 | \
        xargs basename)"

    read -r MAX_BRIGHTNESS < \
    "${SYSFS_CLASS_DIR}/${SYSFS_CLASS_DEV}/max_brightness"

    readonly MAX_BRIGHTNESS

    set -- "${SYSFS_CLASS_DIR}" "${SYSFS_CLASS_DEV}" "${MAX_BRIGHTNESS}"
}

[ -d "$1" ] || {

    die "directory '$1' does not exist"

    exit 1
}

# shellcheck disable=2155
readonly SAVE_BRIGHTNESS="$(get_brightness "${1}/${2}/brightness")"

backlight_control 5

if [ "$(get_brightness "${1}/${2}/brightness")" -eq $(( ($3 * 5) / 100 )) ]; then
    success=$(( success + 1 ))

else
    fail=$(( fail + 1 ))

fi

backlight_control +2

if [ "$(get_brightness "${1}/${2}/brightness")" -eq $(( ($3 * 7) / 100 )) ]; then
    success=$(( success + 1 ))

else
    fail=$(( fail + 1 ))

fi

backlight_control -2

if [ "$(get_brightness "${1}/${2}/brightness")" -eq $(( ($3 * 5) / 100 )) ]; then
    success=$(( success + 1 ))

else
    fail=$(( fail + 1 ))

fi

cat << RESULTS
Test results:
-------------

Successful: ${success}
Failed: ${fail}

Total: $(( fail + success ))

-------------

If you want to restore your original brightness, it was $(( SAVE_BRIGHTNESS * 100 / $3 ))%.
RESULTS
