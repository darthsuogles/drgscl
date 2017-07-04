#!/bin/bash

set -eu

_bsd_="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_bsd_}/params.const.sh"
source "${_bsd_}/lib_pprint.sh"
source "${_bsd_}/lib_wisper_fetch.sh"

##=========================================================
lua_version=5.3.4
lua_version_major="${lua_version%.*}"
infra_lua_install_dir="${drgscl_infra_dir}/pkg/lua/${lua_version}"

luarocks_version=2.4.2
infra_luarocks_install_dir="${drgscl_infra_dir}/pkg/luarocks/${luarocks_version}"

infra_lmod_version=edge
infra_lmod_install_dir="${drgscl_infra_dir}/pkg/Lmod/${infra_lmod_version}"
##=========================================================

# Bootstrap the whole building process
log_info "Prepareing local install directories under ${drgscl_base}"
mkdir -p "${drgscl_base}"
mkdir -p "${drgscl_infra_dir}"
mkdir -p "${drgscl_install_dir}"
mkdir -p "${infra_modules_dir}"

git submodule update --init --recursive --remote

# First install linuxbrew and a few important packages
export LINUXBREW_ROOT="${drgscl_install_dir}/linuxbrew/dev"
export PATH="${LINUXBREW_ROOT}/bin:${PATH:-}"
export CPATH="${LINUXBREW_ROOT}/include:${CPATH:-}"
export LD_LIBRARY_PATH="${LINUXBREW_ROOT}/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="${LINUXBREW_ROOT}/lib/pkgconfig/${PKG_CONFIG_PATH:-}"

(mkdir -p "${drgscl_install_dir}/linuxbrew" && cd $_
 [[ -d dev ]] || git clone https://github.com/Linuxbrew/brew.git dev
 cd dev && git fetch origin && git reset --hard origin/master
 log_info "[infra:brew] building from source (https://github.com/Linuxbrew/brew)"
 
 export HOMEBREW_BUILD_FROM_SOURCE=yes

 brew tap homebrew/dupes
 log_warn "[infra:brew] we leave the package building process for others"
 brew install zlib bzip2 xz
 brew install readline
)

# Installing lua
function fetch_lua {
    log_warn "[infra:lua] trying to infer lua version from its website"
    latest_lua_version=$(_wisper_fetch wget -O- http://www.lua.org/download.html 2>&1 | \
    			     perl -ne 'print "$1\n" if /ftp\/lua-(\d+(\.\d+)+?)\.t(ar\.)?gz/' | \
    			     sort -nr | uniq | head -n1)
    log_info "lua versions: latest ${latest_lua_version}, ours ${lua_version}"
    [[ -n "${lua_version}" ]] || log_errs "[infra:lua] cannot find valid LUA version"
    lua_tarball="lua-${lua_version}.tar.gz"
    [[ -n "${lua_tarball}" ]] || log_errs "[infra:lua] failed to parse lua downloading address"
    _wisper_fetch wget "http://www.lua.org/ftp/${lua_tarball}"
    [[ -f "${lua_tarball}" ]] || log_errs "[infra:lua] failed to download lua ${lua_tarball}"
}

function build_lua {
    log_info "[infra:lua] building from source"
    mkdir -p "${drgscl_base}/pkg/lua" && cd "$_"
    fetch_lua
    [[ "NONE" != "${lua_version}" ]] || quit_with "[infra:lua] failed to acquire lua"

    log_info "[infra:lua] installing"
    if [[ ! -d "${lua_version}" ]]; then
	# TODO: tar output is platform dependent
	lua_extract_dir=$(tar -zxvf "${lua_tarball}" 2>&1 | sed 's@/.*@@' | uniq | perl -pe 's/^\s*x\s+//')
	mv "${lua_extract_dir}" "${lua_version}"
	[[ -d "${lua_version}" ]] || log_errs "[infra:lua] cannot create extracted lua files"
    fi
    cd "${lua_version}"

    CPATH="${LINUXBREW_ROOT}/include:${CPATH}" LIBRARY_PATH="${LINUXBREW_ROOT}/lib:${LIBRARY_PATH:-}" make linux
    make install INSTALL_TOP="${infra_lua_install_dir}"
    ln -s "${infra_lua_install_dir}" "${infra_lua_dir}"
}

[ -d "${infra_lua_dir}/" ] || build_lua
[ -d "${infra_lua_dir}/" ] || log_errs "failed to install lua"
export PATH="${infra_lua_dir}/bin:$PATH"

function build_luarocks {
    mkdir -p "${infra_luarocks_install_dir}" && cd "$_"
    log_info "Installing Luarocks"

    luarocks_tarball="luarocks-${luarocks_version}.tar.gz"
    [[ -f "${luarocks_tarball}" ]] || _wisper_fetch wget "http://luarocks.org/releases/${luarocks_tarball}"
    luarocks_extract_dir=$(
	tar -zxvf "${luarocks_tarball}" 2>&1 | sed 's@/.*@@' | uniq | perl -pe 's/^\s*x\s+//')
    mv "${luarocks_extract_dir}" "${luarocks_version}-src-tree"

    cd "${luarocks_version}-src-tree"
    ./configure --prefix="${infra_luarocks_install_dir}" \
		--sysconfdir="${infra_luarocks_install_dir}/luarocks" \
		--with-lua="${infra_lua_install_dir}" \
		--force-config
    make build && make install
    ln -s "${infra_luarocks_install_dir}" "${infra_luarocks_dir}"
}

# Installing luarocks
[ -d "${infra_luarocks_dir}/" ] || build_luarocks
[ -d "${infra_luarocks_dir}/" ] || log_errs "failed to install luarocks"

# Configure luarocks so that lua can find it
export PATH="${infra_luarocks_dir}/bin:${PATH}"
export LUA_PATH="${infra_luarocks_dir}/share/lua/${lua_version_major}/?.lua;${infra_luarocks_dir}/share/lua/${lua_version_major}/?/init.lua;;"
export LUA_CPATH="${infra_luarocks_dir}/lib/lua/${lua_version_major}/?.so;;"

# Installing required luarocks
for rock in "luasocket" "luaposix" "luafilesystem"; do
    [[ -d "${infra_luarocks_dir}/lib/luarocks/rocks/${rock}" ]] && continue
    luarocks install "${rock}"
done

# Finally, installing the module file
log_info "Installing Lmod"

function build_lmod {
    cd "${_bsd_}/Lmod" && git fetch origin && git reset --hard origin/master
    ./configure --prefix="${infra_lmod_install_dir}" \
		--with-module-root-path="${infra_modules_dir}" \
		--with-spiderCacheDir="${infra_modules_dir}/data/cacheDir" \
		--with-updateSystemFn="${infra_modules_dir}/data/system.txt" \
		--with-tcl=no

    make && make install
    ln -s "${infra_lmod_install_dir}" "${infra_lmod_dir}"
}

[ -d "${infra_lmod_dir}/" ] || build_lmod
[ -d "${infra_lmod_dir}/" ] || log_errs "failed to install Lmod"


touch "${drgscl_base}/.env.sh"
cat <<__EOF_ENV_HEADER__ | tee "${drgscl_base}/.env.sh"
export PATH="${infra_lua_dir}/bin:${infra_luarocks_dir}/bin:\$PATH"
export LD_LIBRARY_PATH="${LINUXBREW_ROOT}/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="${LINUXBREW_ROOT}/lib/pkgconfig/${PKG_CONFIG_PATH}"
export LUA_PATH="$LUA_PATH"
export LUA_CPATH="$LUA_CPATH"

export MODULEPATH="${infra_modules_dir}"
export LMOD_COLORIZE="YES"

__EOF_ENV_HEADER__

cat <<__EOF_ZSH__ > ${HOME}/.zshrc.lmod
source ${drgscl_base}/.env.sh
source ${infra_lmod_dir}/lmod/lmod/init/zsh
__EOF_ZSH__

cat <<__EOF_BASH__ > ${HOME}/.bashrc.lmod
source ${drgscl_base}/.env.sh
source ${infra_lmod_dir}/lmod/lmod/init/bash
__EOF_BASH__

# if [ -f ${_bsd_}/drgscl.sh ]; then (
#     cd ${_bsd_}
#     chmod a+x ./drgscl.sh
#     mkdir -p ./bin
#     cp ./drgscl.sh ./bin/drgscl
#     echo "export PATH=\${PATH}:${_bsd_}/bin" >> ${HOME}/.zshrc.lmod
#     echo "export PATH=\${PATH}:${_bsd_}/bin" >> ${HOME}/.bashrc.lmod
# ) fi

log_info "so here we go"
