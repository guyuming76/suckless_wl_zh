# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic savedconfig toolchain-funcs

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://gitee.com/guyuming76/dwl"
	inherit git-r3
	WLROOTS_SLOT="0/16"
fi

DESCRIPTION="DWL with fcitx5 support"
HOMEPAGE="https://gitee.com/guyuming76/dwl/"

LICENSE="CC0-1.0 GPL-3 MIT"
SLOT="0"
IUSE="X +waybar"

RDEPEND="
	dev-libs/libinput:=
	dev-libs/wayland
	gui-libs/wlroots:${WLROOTS_SLOT}[X(-)?]
	x11-libs/libxkbcommon
	X? (
		x11-libs/libxcb:=
		x11-libs/xcb-util-wm
	)
	waybar? (
		gui-apps/waybar
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-libs/wayland-protocols
	dev-util/wayland-scanner
	virtual/pkgconfig
"

src_prepare() {
	restore_config config.h

	default
}

src_configure() {
	sed -i "s:/local::g" config.mk || die

	sed -i "s:pkg-config:$(tc-getPKG_CONFIG):g" config.mk || die

	if use X; then
		append-cppflags '-DXWAYLAND'
		append-libs '-lxcb' '-lxcb-icccm'
	fi
}

src_install() {
	default

	insinto /usr/bin
# -rwxr_xr_x
        insopts -m0755
                doins xdg_run_user
		doins dwl.sh
		doins dwlstart.sh

	save_config config.h
}
