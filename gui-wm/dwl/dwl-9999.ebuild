# Copyright 2022-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# live 版本：跟 dwl-0.9.ebuild 是同一分支（0.9_guyuming）的同一套构建逻辑，
# 两者只在 KEYWORDS 上不同——改了 0.9 记得同步改这里。
inherit savedconfig git-r3 toolchain-funcs

# gitee 现在对匿名 https git 访问一律要求登录（terminal prompts disabled 时直接失败），
# 所以主源用 codeberg 镜像（匿名可读），gitee 只作为配了凭据时的回退。
# 想强制走 gitee：在 /etc/portage/env/gui-wm/dwl 里写
#   EGIT_OVERRIDE_REPO_GUYUMING76_DWL="https://<用户名>:<token>@gitee.com/guyuming76/dwl"
EGIT_REPO_URI="
	https://codeberg.org/guyuming76/dwl.git
	https://gitee.com/guyuming76/dwl
"
EGIT_BRANCH="0.9_guyuming"

DESCRIPTION="DWL with fcitx5 support"
HOMEPAGE="https://gitee.com/guyuming76/dwl/"

LICENSE="CC0-1.0 GPL-3+ MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+seatd X +foot +wmenu +fcitx +handwrite +grim +imv +mpv +rfm wf-recorder +wl-clipboard xwlclip"

# 0.9_guyuming 的 config.mk 里硬编码了 wlroots-0.20（不再像 0.7cn 那样用 wlroots-0.18）
WLROOTS_DEP="
	>=gui-libs/wlroots-0.20:0.20=[libinput,session,X?]
"

CDEPEND="
	${WLROOTS_DEP}
	dev-libs/libinput:=
	dev-libs/wayland
	x11-libs/libxkbcommon
	xwlclip? (
		x11-libs/libxcb:=
	)
	X? (
		x11-libs/libxcb:=
		x11-libs/xcb-util-wm
	)
"

RDEPEND="
	${CDEPEND}
	X? (
		x11-base/xwayland
	)
	wmenu? (
		gui-apps/wmenu
	)
	foot? (
		gui-apps/foot
	)
	grim? (
		gui-apps/grim
		gui-apps/slurp
	)
	imv? (
		media-gfx/imv[wayland,jpeg,png,gif,svg,tiff]
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
		app-i18n/fcitx:5[wayland]
		app-i18n/fcitx-chinese-addons:5
		app-i18n/fcitx-gtk:5[wayland]
		media-fonts/wqy-zenhei
	)
	handwrite? (
		app-i18n/fcitx-handwrite
	)
	rfm? (
		gui-apps/rfm[wayland]
	)
	seatd? (
		sys-auth/seatd[builtin,server,-elogind,-systemd]
	)
"
# gui-apps/wtype::guru
# fcitx:5::gentoo-zh

# uses <linux/input-event-codes.h>
DEPEND="
	${CDEPEND}
	sys-kernel/linux-headers
"

# 0.9 的 Makefile 要用 wayland-protocols 的 staging 协议：
#   cursor-shape-v1(1.32)、ext-workspace-v1(1.34)、ext-image-copy-capture-v1(1.36)
#   xwlclip 另外还要 staging 的 ext-data-control-v1(1.36)
BDEPEND="
	>=dev-libs/wayland-protocols-1.36
	dev-util/wayland-scanner
	virtual/pkgconfig
"

src_prepare() {
	restore_config config.h

	default
}

# 0.7cn 的 config.mk 里 XWAYLAND/XLIBS 是写死的注释行，只能靠 sed 打开/删除；
# 0.9 改成命令行覆盖 make 变量（比 sed 稳，也不怕 CMake 风格改写）：
#   - PKG_CONFIG 覆盖 config.mk 里的 PKG_CONFIG = pkg-config
#   - CC 覆盖 config.mk 里的 CC = cc（不覆盖的话 gcc / 交叉编译环境会被忽略）
#   - XWAYLAND / XLIBS 覆盖 config.mk 里被注释掉的那两行（0.7cn 时 sed 其实没起作用）
#   - HANDWRITE 对应 config.mk 默认打开的 -DHANDWRITE
#   - PREFIX 在 src_install 时覆盖，config.mk 里的 /usr/local 就不会用到
src_compile() {
	emake \
		PKG_CONFIG="$(tc-getPKG_CONFIG)" \
		CC="$(tc-getCC)" \
		XWAYLAND="$(usev X -DXWAYLAND)" \
		XLIBS="$(usev X "xcb xcb-icccm")" \
		HANDWRITE="$(usev handwrite -DHANDWRITE)" \
		dwl

	# Xwayland.sh 会用 xwlclip 给 rootful Xwayland 做剪贴板桥（有自己独立的 Makefile）
	if use xwlclip; then
		emake -C xwlclip CC="$(tc-getCC)"
	fi
}

src_install() {
	# dwl + Xwayland.sh + dwl.1 + dwl.desktop
	emake DESTDIR="${D}" PREFIX="${EPREFIX}/usr" install

	insinto /usr/bin
# -rwxr_xr_x
	insopts -m0755
	doins xdg_run_user
	doins dwl.sh
	doins dwlstart.sh
	doins screenshot.sh

	if use xwlclip; then
		# xwlclip 的 Makefile 用 install -Dm755 xwlclip $(PREFIX)/bin/xwlclip，
		# 没有 DESTDIR，所以 PREFIX 要给完整镜像路径（ED = D + EPREFIX）
		emake -C xwlclip PREFIX="${ED}/usr" install
	fi

	dodoc CHANGELOG.md README.md wemeet-screenshare.md

	save_config config.h
}

pkg_postinst() {
	if use seatd; then
		elog "若使用 OpenRC：rc-update add seatd default && rc-service seatd start"
	fi
	if use X; then
		elog "注意：X 选项是 Xwayland rootless 模式；本 fork 文档里讲的 rootful"
		elog "Xwayland（Xwayland.sh，跑 dwm + 腾讯会议）需要不带 X 编译，两条路互斥。"
	fi
	elog "自定义 config.h：把 /etc/portage/savedconfig/${CATEGORY}/${PF}"
	elog "改好后再装一次即可生效（源码改动用 savedconfig 的 restore 机制回灌）。"
}
