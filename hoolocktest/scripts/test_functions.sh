#set -o xtrace

error_exit() {
    printf "Error: $1\n";
    exit 1;
}

require_dir_exists() {
    if [ -d "$1" ]; then
        return;
    fi
    error_exit "$1 does not exist!";
}

require_file_exists() {
    if [ -f "$1" ]; then
        return;
    fi
    error_exit "$1 does not exist!";
}

require_block_exists() {
    if [ -b "$1" ]; then
        return;
    fi
    error_exit "$1 does not exist!";
}

require_char_exists() {
    if [ -c "$1" ]; then
        return;
    fi
    error_exit "$1 does not exist!";
}
