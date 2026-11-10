# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

if [[ ${PV} == *9999 ]]; then
	# gitee 匿名 git 已被要求登录，主源用 codeberg 镜像（注意仓库名是 fcitx-handwrite，
	# 比 gitee 上的 fcitx-handwriting 少个 ing），gitee 作回退。
	# 分支必须显式指定：只有 work_with_rfm_grepMatch 带 theme/fcitx-handwriting.{svg,desktop}
	# 这两个 src_install 要装的文件（codeberg 的默认分支也正是它）。
	EGIT_REPO_URI="
		https://codeberg.org/guyuming76/fcitx-handwrite.git
		https://gitee.com/guyuming76/fcitx-handwriting.git
	"
	EGIT_BRANCH="work_with_rfm_grepMatch"
	inherit git-r3
fi

DESCRIPTION="Chinese charactor handwrite input that works with wayland compositor DWL"
HOMEPAGE="https://codeberg.org/guyuming76/fcitx-handwrite"
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
