# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic savedconfig toolchain-funcs git-r3

EGIT_REPO_URI="https://gitee.com/guyuming76/dwl"

DESCRIPTION="DWL with fcitx5 support"
HOMEPAGE="https://gitee.com/guyuming76/dwl/"

LICENSE="CC0-1.0 GPL-3 MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="X waybar +foot +bemenu +fcitx +grim +imv +mpv +rfm wf-recorder +wl-clipboard"

RDEPEND="
	dev-libs/libinput:=
	dev-libs/wayland
	gui-libs/wlroots[X(-)?]
	x11-libs/libxkbcommon
	X? (
		x11-libs/libxcb:=
		x11-libs/xcb-util-wm
	)
	bemenu? (
		dev-libs/bemenu
	)
	foot? (
		gui-apps/foot
	)
	waybar? (
		gui-apps/waybar
		sys-fs/inotify-tools
		gui-apps/wtype
	)
	grim? (
		gui-apps/grim
		gui-apps/slurp
	)
	imv? (
		media-gfx/imv
	)
	mpv? (
		media-video/mpv
	)
	wf-recorder? (
		gui-apps/wf-recorder
	)
	wl-clipboard? (
		gui-apps/wl-clipboard
	)
	fcitx? (
		app-i18n/fcitx:5
		app-i18n/fcitx-chinese-addons:5
		app-i18n/fcitx-gtk:5
		media-fonts/wqy-zenhei
	)
	rfm? (
		gui-apps/rfm[wayland]
	)
"
# gui-apps/wtype::guru
# fcitx:5::gentoo-zh

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
		doins screenshot.sh

	if use waybar; then
		doins waybar/waybar-dwl.sh
		doins waybar/dwlstart.sh
		doins waybar/sleep.sh

		insinto /etc/xdg/waybar
		insopts -m0644
		doins waybar/style_dwl.css
		doins waybar/config_dwl

	else
		doins dwlstart.sh
	fi

	save_config config.h

}
