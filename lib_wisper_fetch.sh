
# Internet resource acquisition
REQ_HEADER="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/601.5.17 (KHTML, like Gecko) Version/9.1 Safari/601.5.17"

function _fetch_with_curl {
    curl -A "${USER_AGENT}" "$@"
}
function _fetch_with_wget {
    wget --header="${REQ_HEADER}" --user-agent="${USER_AGENT}" "$@"
}
function _wisper_fetch {    
    [[ $# -ge 1 ]] || quit_with "usage: _wisper_fetch <wget|curl> ..."
    local cmd=$1; shift

    case "${cmd}" in
	curl) _fetch_with_curl "$@" && return 0 ;;
	wget) _fetch_with_wget "$@" && return 0 ;;
	\?) log_errs "do not recognize download command ";
	    _fetch_with_curl $@ || _fetch_with_wget $@ || return 1 ;;
    esac
}
