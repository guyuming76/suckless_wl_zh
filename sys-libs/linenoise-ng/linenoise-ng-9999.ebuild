# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://github.com/arangodb/linenoise-ng"
	inherit git-r3
fi

DESCRIPTION="simple alternative for gnu readline"
HOMEPAGE="https://github.com/arangodb/linenoise-ng"
LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

EGIT_SUBMODULES=()

RDEPEND="
"

BDEPEND="
"

src_prepare(){
	append-flags -fPIC
	cmake_src_prepare
}

#https://forums.gentoo.org/viewtopic-p-8849261.html#8849261
# is it possible to using code like what follows? it looks more cmake way.
#src_configure() {
#        local mycmakeargs=(
#		-DCMAKE_C_FLAGS_RELEASE="${CFLAGS} -fPIC"
#        )
#        cmake_src_configure
#}
# -DCMAKE_INSTALL_PREFIX=/usr
# -DCMAKE_C_FLAGS_RELEASE="${CFLAGS} -fPIC"
