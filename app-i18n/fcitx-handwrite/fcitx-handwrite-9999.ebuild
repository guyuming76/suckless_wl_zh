# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://gitee.com/guyuming76/fcitx-handwriting"
	inherit git-r3
fi

DESCRIPTION="Chinese charactor handwrite input that works with wayland compositor DWL"
HOMEPAGE="https://gitee.com/guyuming76/fcitx-handwriting"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64"

EGIT_SUBMODULES=()

RDEPEND="
	app-i18n/zinnia
	app-i18n/zinnia-tomoe
	>=dev-libs/glib-2.74
"

BDEPEND="
	x11-libs/gtk+:3[wayland]
"

src_install() {
	cmake_src_install

	insinto /usr/share/icons/hicolor/scalable/apps/
	doins theme/fcitx-handwriting.svg

	insinto /usr/share/applications
	doins theme/fcitx-handwriting.desktop
}

pkg_postinst() {
	cmake_pkg_postinst

	mkdir -p /usr/lib/zinnia/model/tomoe/
	ln -s /usr/lib64/zinnia/model/tomoe/handwriting-zh_CN.model /usr/lib/zinnia/model/tomoe/handwriting-zh_CN.model

	gtk-update-icon-cache -f /usr/share/icons/hicolor
	update-desktop-database
}

pkg_postrm() {
	cmake_pkg_postrm

	gtk-update-icon-cache -f /usr/share/icons/hicolor
	update-desktop-database
}
