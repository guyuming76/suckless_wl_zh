# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop savedconfig xdg-utils

#`cargo.eclass` 包含一个关键函数 `cargo_gen_config`，它会在构建过程中被调用。这个函数的作用是：
#1.  **检查系统环境中是否已经存在可用的、版本足够的 `rustc` 和 `cargo`**。
#2.  如果存在，就生成一个指向系统现有工具链的 Cargo 配置文件（通常在 `~/.cargo/config.toml`），并**直接使用它**。
#3.  如果不存在，或者版本太旧，它才会**回退到使用通过 `BDEPEND` 声明的 Gentoo 包**（如 `virtual/rust`）。
#这意味着，只要用户系统里有任何可用的 Rust（无论是 Gentoo 安装的还是 `rustup` 安装的），`cargo.eclass` 都会优先使用它。

# 但只有 USE=reedline 才真的需要 Rust。`CARGO_OPTIONAL`（必须在 inherit 之前设置）
# 让 cargo.eclass 不自动往 BDEPEND 里塞 dev-lang/rust(-bin)、也不导出它的 src_* 阶段：
# 默认用 prompt_toolkit 的用户就不必为一个 C 程序去装整套 Rust 工具链。
# 代价是 rust_pkg_setup 要我们自己按 USE 调用（见 pkg_setup），
# 以及 Rust 的 BDEPEND 要自己写（见 BDEPEND）。
CARGO_OPTIONAL=1
inherit cargo

if [[ ${PV} == *9999 ]]; then
	# gitee 现在对匿名 https git 一律返回 401（要登录），所以主源换成 github 镜像，
	# gitee 只作为配了凭据时的回退。
	# github 上的默认分支就是开发分支 autoWithTitle，这里显式写出来：万一哪天
	# 默认分支被切到老的 master，也不会静默构建成旧代码。
	EGIT_REPO_URI="
		https://github.com/guyuming76/rfm.git
		https://gitee.com/guyuming76/rfm
	"
	EGIT_BRANCH="autoWithTitle"
	inherit git-r3
fi

DESCRIPTION="suckless style file manager"
HOMEPAGE="https://github.com/guyuming76/rfm"
LICENSE="GPL-3"
SLOT="0"

# 行编辑后端三选一，一一对应上游 config.mk 里的 READLINE_LIB：
#   gnu-readline   -> -DGNU_readline    （sys-libs/readline，功能最少）
#   reedline       -> -Dreedline        （Rust nushell reedline，要 Rust 工具链）
#   prompt-toolkit -> -Dprompt_toolkit  （嵌入式 Python + dev-python/prompt_toolkit）
# 上游 autoWithTitle 分支的 config.mk 现在默认就是 prompt_toolkit，这里跟上。
IUSE="+debug +wayland +git +locate gnu-readline reedline +prompt-toolkit"

# 关键：REQUIRED_USE 的 `^^`（exactly-one-of）把三个开关锁成「有且只有一个」。
# 用户要是同时开了两个（比如老的 package.use 里留着 reedline，而现在
# prompt-toolkit 是默认开的），portage 会在算依赖时就报错并指出该关掉哪个，
# 而不是让 ebuild 去猜用户想要哪个后端。
REQUIRED_USE="
	debug ^^ ( gnu-readline reedline prompt-toolkit )
"
EGIT_SUBMODULES=()

# 注意 config.mk 里 PythonEmbedded 默认就是开着的（http/ftp 分享用得上它，
# 而 prompt_toolkit 后端更是非它不可，Makefile 里直接 $(error) 强制要求），
# 所以无论选哪个后端，构建期都需要 python3-config / Python.h，
# 运行期也都需要能加载 libpython。
# 这里故意在 DEPEND/RDEPEND 里直接依赖 dev-lang/python，不用 python-any-r1 /
# python-single-r1：上游 Makefile
# 里写死了 `python3-config --cflags/--ldflags --embed`（跟着 eselect 选中的
# python3 走），用 eclass 固定 EPYTHON 反而会和它打架。pkgcheck 的
# MissingPythonEclass 提示因此是已知且有意保留的。
DEPEND="
	app-text/cmark
	dev-lang/python
	>=dev-libs/glib-2.74
	dev-libs/json-glib
	sys-libs/readline
	x11-libs/gtk+:3[wayland?]
"
BDEPEND="
	virtual/pkgconfig
	reedline? ( || (
		dev-lang/rust
		dev-lang/rust-bin
		)
	)
"
RDEPEND="
	>=dev-libs/glib-2.74
	app-text/cmark
	dev-lang/python
	dev-libs/json-glib
	dev-util/desktop-file-utils
	dev-util/gtk-update-icon-cache
	sys-libs/readline
	x11-libs/gtk+:3[wayland?]
	x11-misc/xdg-utils
	locate? ( || (
		sys-apps/plocate
		sys-apps/mlocate
		)
	)
	git? (
		dev-vcs/git
	)
	prompt-toolkit? ( dev-python/prompt-toolkit )
"

#x11-misc/xdg-utils
#dev-util/desktop-file-utils
export CalledByEbuild="YES"

# 上游把 UI 语言做成 config.mk 里的 languageInclude（Chinese.h / English.h），
# 这个选择在 src_configure 和 src_install 都要用，抽成一个函数避免两处逻辑漂移。
_rfm_language_header() {
	if [[ -z $(locale | grep -i zh_CN) ]]; then
		echo English.h
	else
		echo Chinese.h
	fi
}

pkg_setup() {
	# CARGO_OPTIONAL=1 时 eclass 不会自动调用 rust_pkg_setup，这里按 USE 手动调，
	# 它负责挑出可用的 Rust 版本并设置 ${CARGO}。
	use reedline && rust_pkg_setup
}

src_unpack() {
	git-r3_src_unpack

	if use reedline; then
		# reedline 后端要在两个子目录里各构建一个 crate（reedline_wrapper 和
		# rfmReedline），而 cargo_live_src_unpack 只会在 ${S} 里跑 cargo fetch/vendor。
		#
		# 每个 crate 必须配一套独立的 CARGO_HOME（内含指向自己 vendor 目录的
		# config.toml）和独立的 vendor 目录：cargo 第二次 vendor 到同一个目录时
		# 会把上一个 crate 需要、而自己不需要的 crate 剪掉，而 build 阶段
		# config.toml 里是 [net] offline = true，缺一个 crate 就构建失败。
		local crate
		for crate in reedline_wrapper rfmReedline; do
			# 注意 S=... 只作用于 cargo_live_src_unpack 这一次调用（bash 的
			# 前缀赋值不会外泄），所以循环下一轮 S 仍然是 ${S}。
			ECARGO_HOME="${WORKDIR}/cargo_home-${crate}" \
			ECARGO_VENDOR="${WORKDIR}/vendor-${crate}" \
			S="${S}/${crate}" \
				cargo_live_src_unpack || die "failed to vendor deps of ${crate}"
		done
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

	# READLINE_LIB 三选一。这里不依赖上游当前默认值（上游会把这行改来改去，
	# 也可能把另两种写成注释），做法是：把现有的有效赋值行全部注释掉，
	# 再把选中的那一行追加到文件末尾（make 取最后一次赋值，所以一定生效）。
	local readline_lib
	if use gnu-readline; then
		readline_lib="-DGNU_readline"
	elif use reedline; then
		readline_lib="-Dreedline"
	else
		readline_lib="-Dprompt_toolkit"
	fi
	sed -i -E "s@^[[:space:]]*READLINE_LIB[[:space:]]*=.*@#&@" config.mk || die
	printf '\n# READLINE_LIB set by rfm-9999.ebuild from USE flags\nREADLINE_LIB = %s\n' \
		"${readline_lib}" >> config.mk || die
	grep -q "^READLINE_LIB = ${readline_lib}$" config.mk \
		|| die "failed to set READLINE_LIB in config.mk"

	# Makefile 里 prompt_toolkit 分支强制要求 PythonEmbedded，这里确保打开
	# （上游默认已开着，但万一哪天上游把它关掉，也不至于构建到一半才 $(error)）
	if use prompt-toolkit; then
		sed -i -E "s@^[[:space:]]*PythonEmbedded[[:space:]]*=.*@#&@" config.mk || die
		printf '\n# PythonEmbedded forced on by USE=prompt-toolkit\nPythonEmbedded = -DPythonEmbedded\n' \
			>> config.mk || die
	fi

	# Are there any better way to check language setting?
	if [[ $(_rfm_language_header) != Chinese.h ]]; then
		sed -i "s:Chinese.h:English.h:g" config.mk || die
	fi
}

src_compile() {
	# 如果使用 reedline，先构建 Rust 部分（两个 crate 各用各的 CARGO_HOME，
	# 这样 cargo 才会读到各自那份指向本地 vendor 目录的 config.toml）
	if use reedline; then
		local crate rfm_version
		# 上游把版本号写在 config.mk 的第一行（cargo.eclass 不再提供 ${VERSION}），
		# reedline_wrapper 的 build.rs 需要它来建立符号链接。
		rfm_version=$(sed -n 's/^VERSION[[:space:]]*=[[:space:]]*//p' config.mk | head -n 1)

		for crate in reedline_wrapper rfmReedline; do
			pushd "${crate}" >/dev/null || die
			export CARGO_HOME="${WORKDIR}/cargo_home-${crate}"
			RFM_VERSION="${rfm_version}" cargo_src_compile
			popd >/dev/null || die
		done
	fi
	# 然后构建 C 部分
	emake
}

src_install() {
	default

	save_config config.h

	insinto /usr/share/icons/hicolor/scalable/apps
	doins rfm.svg

	domenu rfm.desktop

	insinto /usr/include
	doins rfm_addon.h
	# 上游 Makefile 把语言头的安装包在 `ifneq ($(CalledByEbuild),YES)` 里面，
	# 即由 ebuild 负责装；但 rfm 编译插件时会 -include
	# /usr/include/rfmLanguage.h（见 -DRFM_Language_H_filepath），
	# 所以这里必须把选中的语言头装成 rfmLanguage.h，否则插件编译会失败。
	newins "$(_rfm_language_header)" rfmLanguage.h

	#xdg-mime default rfm.desktop inode-directory
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
