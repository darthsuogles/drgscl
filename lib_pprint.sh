# -*- shell-script -*-

# Helper functions
function _lpp_set_color {
    local _fg=3; local _bg=4
    local _r=${1:-255}; local _g=${2:-0}; local _b=${3:-0}
    printf '\e[0;%s8;2;%s;%s;%sm▒▒▒ ' "$_fg" "$_r" "$_g" "$_b"    
}
function _lpp {
    severity="$1"; shift
    local orig_msg="$@"
    local timestamp="$(date -u "+%F %H:%M:%S %a (UTC)")"
    local msg=
    case "${severity}" in
	INFO)
	    _lpp_set_color 000 143 127 ;;
	DEBUG)
	    _lpp_set_color 191 127 000 ;;
	WARNING)
	    _lpp_set_color 191 000 255 ;;
	ERROR)
	    _lpp_set_color 255 000 000 ;;
	\?);;
    esac
    printf "${timestamp} [drgscl] @ ${severity}: ${orig_msg}"
    printf '\e[m\n'
}
# https://unix.stackexchange.com/questions/269077/tput-setaf-color-table-how-to-determine-color-codes
function log_info() { _lpp "INFO" "$@"; }
function log_warn() { _lpp "WARNING" "$@"; }
function log_errs() { _lpp "ERROR" "$@"; }
function quit_with() { log_errs "$@"; exit 1; }
