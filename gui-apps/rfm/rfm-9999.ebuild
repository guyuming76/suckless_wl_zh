# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit savedconfig xdg-utils

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://gitee.com/guyuming76/rfm"
	inherit git-r3
fi

DESCRIPTION="suckless style file manager"
HOMEPAGE="https://gitee.com/guyuming76/rfm/"
LICENSE="GPL-3"
SLOT="0"
IUSE="+wayland +git +locate +readline linenoise-ng"

EGIT_SUBMODULES=()

BDEPEND="
	virtual/pkgconfig
	x11-libs/gtk+:3[wayland?]
	app-text/cmark
	readline? (
		sys-libs/readline
	)
	linenoise-ng? (
		sys-libs/linenoise-ng
	)
"
RDEPEND="
	>=dev-libs/glib-2.74
	locate? ( || (
		sys-apps/plocate
		sys-apps/mlocate
		)
	)
	git? (
		dev-vcs/git
	)
"
#x11-misc/xdg-utils
#dev-util/desktop-file-utils

src_prepare() {
	restore_config config.h

	default
}

src_configure() {
	sed -i "s:/local::g" config.mk || die
	if ! use git; then
		sed -i "s:-DGitIntegration::g" config.mk || die
	fi

# Are there any better way to check language setting?
	if [[ -z "$(locale | grep -i zh_CN)" ]]; then
		sed -i "s:Chinese.h:English.h:g" config.mk || die
	fi
}

src_install() {
	export CalledByEbuild="YES"
	default

	save_config config.h

	insinto /usr/share/icons/hicolor/scalable/apps
	doins rfm.svg

	insinto /usr/share/applications
	doins rfm.desktop

	#xdg-mime default rfm.desktop inode/directory
}

pkg_postinst() {
	gtk-update-icon-cache -f /usr/share/icons/hicolor
	xdg_desktop_database_update
	xdg_mimeinfo_database_update
	#after install run    xdg-mime query default inode/directory    to check, rfm.desktop should be returned
	#update-desktop-database
}

pkg_postrm() {
	gtk-update-icon-cache -f /usr/share/icons/hicolor
	xdg_desktop_database_update
	xdg_mimeinfo_database_update
	#after install run    xdg-mime query default inode/directory    to check, rfm.desktop should NOT be returned
	#update-desktop-database
}
