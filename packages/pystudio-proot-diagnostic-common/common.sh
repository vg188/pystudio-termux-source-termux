# Shared recipe helpers for PyStudio PRoot diagnostic variants.

_pystudio_proot_variant_dir() {
	printf '%s/libexec/pystudio-proot-tests/%s' "$TERMUX_PREFIX" "$PYSTUDIO_PROOT_VARIANT"
}

_pystudio_proot_apply_patch() {
	local patch_name="$1"
	local patch_path="$TERMUX_PKG_BUILDER_DIR/../pystudio-proot-diagnostic-common/$patch_name"
	[[ -f "$patch_path" ]] || {
		echo "Missing PyStudio PRoot patch: $patch_path" >&2
		exit 1
	}
	patch --silent -l -p1 < "$patch_path"
}

pystudio_proot_variant() {
	PYSTUDIO_PROOT_VARIANT="$1"
	local version_suffix="$2"
	local base_version="${PYSTUDIO_PROOT_BASE_VERSION:-5.1.107.81}"
	local src_ref="${PYSTUDIO_PROOT_SRC_REF:-v${base_version}}"
	local src_sha256="${PYSTUDIO_PROOT_SRC_SHA256:-08c9071fb0d208cdaaf98a29ba4293716fa7ec0f875c51eab153b35b53a4f4d6}"

	TERMUX_PKG_HOMEPAGE=https://proot-me.github.io/
	TERMUX_PKG_DESCRIPTION="PyStudio PRoot diagnostic variant: ${PYSTUDIO_PROOT_VARIANT}"
	TERMUX_PKG_LICENSE="GPL-2.0"
	TERMUX_PKG_MAINTAINER="PyStudio"
	TERMUX_PKG_VERSION="${base_version}+pystudio.${version_suffix}"
	TERMUX_PKG_SRCURL="https://github.com/termux/proot/archive/${src_ref}.zip"
	TERMUX_PKG_SHA256="$src_sha256"
	TERMUX_PKG_DEPENDS="libandroid-shmem, libtalloc"
	TERMUX_PKG_BUILD_IN_SRC=true
	TERMUX_PKG_AUTO_UPDATE=false
	TERMUX_PKG_EXTRA_MAKE_ARGS="-C src PROOT_WITH_LIBANDROID_SHMEM=true BINDIR=$(_pystudio_proot_variant_dir) PROOT_UNBUNDLE_LOADER_INSTALL_DIR=$(_pystudio_proot_variant_dir)"
	TERMUX_PKG_NO_SHEBANG_FIX_FILES="bin/pystudio-proot-test-${PYSTUDIO_PROOT_VARIANT}"
	export PROOT_UNBUNDLE_LOADER=true

	if [[ "${PYSTUDIO_PROOT_STATIC:-false}" == "true" ]]; then
		TERMUX_PKG_DESCRIPTION="PyStudio PRoot diagnostic variant: ${PYSTUDIO_PROOT_VARIANT} (static link attempt)"
		TERMUX_PKG_DEPENDS=""
		TERMUX_PKG_BUILD_DEPENDS="libtalloc"
		TERMUX_PKG_EXTRA_MAKE_ARGS="-C src BINDIR=$(_pystudio_proot_variant_dir) PROOT_UNBUNDLE_LOADER_INSTALL_DIR=$(_pystudio_proot_variant_dir)"
	fi
}

termux_step_pre_configure() {
	CPPFLAGS+=" -DARG_MAX=131072"
	LDFLAGS="$(printf '%s\n' "$LDFLAGS" | sed "s#-Wl,-rpath=$TERMUX_PREFIX/lib##g")"

	_pystudio_proot_apply_patch pystudio-runtime-loader-paths.patch

	for patch_name in ${PYSTUDIO_PROOT_EXTRA_PATCHES:-}; do
		_pystudio_proot_apply_patch "$patch_name"
	done
	if [[ "${PYSTUDIO_PROOT_FORK_TRACE:-false}" == "true" ]]; then
		CPPFLAGS+=" -DPYSTUDIO_FORK_TRACE"
	fi

	if [[ "${PYSTUDIO_PROOT_DISABLE_SECCOMP:-false}" == "true" ]]; then
		CPPFLAGS+=" -DPYSTUDIO_DISABLE_SECCOMP_FILTER"
	fi
	if [[ "${PYSTUDIO_PROOT_DISABLE_PROCESS_VM:-false}" == "true" ]]; then
		CPPFLAGS+=" -DPYSTUDIO_DISABLE_PROCESS_VM"
	fi
	if [[ "${PYSTUDIO_PROOT_STATIC:-false}" == "true" ]]; then
		LDFLAGS+=" -static"
	fi
}

termux_step_post_make_install() {
	local target_dir wrapper
	target_dir="$(_pystudio_proot_variant_dir)"
	wrapper="$TERMUX_PREFIX/bin/pystudio-proot-test-${PYSTUDIO_PROOT_VARIANT}"

	chmod 755 "$target_dir/proot"
	[[ ! -f "$target_dir/loader" ]] || chmod 755 "$target_dir/loader"
	[[ ! -f "$target_dir/loader32" ]] || chmod 755 "$target_dir/loader32"

	mkdir -p "$TERMUX_PREFIX/bin"
	cat > "$wrapper" <<EOF
#!/system/bin/sh
if [ -z "\${PREFIX:-}" ]; then
	case "\$0" in
		*/bin/pystudio-proot-test-${PYSTUDIO_PROOT_VARIANT}) PREFIX=\${0%/bin/pystudio-proot-test-${PYSTUDIO_PROOT_VARIANT}} ;;
		*) SCRIPT_DIR=\${0%/*}; PREFIX=\$(cd "\$SCRIPT_DIR/.." 2>/dev/null && pwd -P) || exit 1 ;;
	esac
fi
loader_dir="\$PREFIX/libexec/pystudio-proot-tests/${PYSTUDIO_PROOT_VARIANT}"
[ ! -f "\$loader_dir/loader" ] || export PROOT_LOADER="\$loader_dir/loader"
[ ! -f "\$loader_dir/loader32" ] || export PROOT_LOADER_32="\$loader_dir/loader32"
exec "\$loader_dir/proot" "\$@"
EOF
	chmod 755 "$wrapper"
}

