PYSTUDIO_PROOT_FORK_TRACE=true
PYSTUDIO_PROOT_EXTRA_PATCHES="pystudio-fork-trace.patch pystudio-fork-to-clone-seccomp.patch pystudio-signal-trace.patch"
_pystudio_package_dir="${TERMUX_PKG_BUILDER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"
. "$_pystudio_package_dir/../pystudio-proot-diagnostic-common/common.sh"
pystudio_proot_variant "fork-to-clone-signal-trace" "fork.to.clone.signal.trace"
unset _pystudio_package_dir
