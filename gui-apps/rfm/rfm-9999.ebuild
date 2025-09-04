# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit savedconfig xdg-utils cargo

#`cargo.eclass` 包含一个关键函数 `cargo_gen_config`，它会在构建过程中被调用。这个函数的作用是：
#1.  **检查系统环境中是否已经存在可用的、版本足够的 `rustc` 和 `cargo`**。
#2.  如果存在，就生成一个指向系统现有工具链的 Cargo 配置文件（通常在 `~/.cargo/config.toml`），并**直接使用它**。
#3.  如果不存在，或者版本太旧，它才会**回退到使用通过 `BDEPEND` 声明的 Gentoo 包**（如 `virtual/rust`）。
#这意味着，只要用户系统里有任何可用的 Rust（无论是 Gentoo 安装的还是 `rustup` 安装的），`cargo.eclass` 都会优先使用它。

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://gitee.com/guyuming76/rfm"
	inherit git-r3
fi

DESCRIPTION="suckless style file manager"
HOMEPAGE="https://gitee.com/guyuming76/rfm/"
LICENSE="GPL-3"
SLOT="0"
IUSE="+debug +wayland +git +locate +reedline"
REQUIRED_USE="debug"
EGIT_SUBMODULES=()

BDEPEND="
	virtual/pkgconfig
	x11-libs/gtk+:3[wayland?]
	app-text/cmark
	sys-libs/readline
	dev-libs/json-glib
	reedline? ( || (
		dev-lang/rust
		dev-lang/rust-bin
		)
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
export CalledByEbuild="YES"

src_unpack() {
	git-r3_src_unpack
	if use reedline; then
		S="${S}/reedline_wrapper" cargo_live_src_unpack
	fi
}

src_prepare() {
	restore_config config.h

	default
}

src_configure() {
	#cargo_gen_config

	sed -i "s:/local::g" config.mk || die
	if ! use git; then
		sed -i "s:-DGitIntegration::g" config.mk || die
	fi
	if ! use reedline; then
		sed -i "s:-Dreedline:-DGNU_readline:g" config.mk || die
	fi
# Are there any better way to check language setting?
        if [[ -z "$(locale | grep -i zh_CN)" ]]; then
                sed -i "s:Chinese.h:English.h:g" config.mk || die
	fi
}

src_compile() {
    # 如果使用 reedline，先构建 Rust 部分
    if use reedline; then
        pushd reedline_wrapper >/dev/null || die
        cargo_src_compile
        popd >/dev/null || die
        pushd rfmReedline >/dev/null || die
	cargo_src_compile
        popd >/dev/null || die
    fi
    # 然后构建 C 部分
    emake
}

src_install() {
	default

	save_config config.h

	insinto /usr/share/icons/hicolor/scalable/apps
	doins rfm.svg

	insinto /usr/share/applications
	doins rfm.desktop

	insinto /usr/include
	doins rfm_addon.h

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
