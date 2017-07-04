# -*- shell-script -*-
set -eu

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

drgscl_base="${HOME}/.drgscl"

# Packages will be installed here
drgscl_install_dir="${drgscl_base}/cellar"

# Build infra: Lmod, lua
drgscl_infra_dir="${drgscl_base}/infra"

# Infra setup
infra_lmod_dir="${drgscl_infra_dir}/Lmod"

# Module files
infra_modules_dir="${drgscl_base}/modulefiles"

# Lmod deps: Lua
infra_lua_dir="${drgscl_infra_dir}/lua"

# Lmod deps: luarocks
infra_luarocks_dir="${drgscl_infra_dir}/luarocks"

drgscl_infra_lmod_init="${infra_lmod_dir}/lmod/lmod/init"

