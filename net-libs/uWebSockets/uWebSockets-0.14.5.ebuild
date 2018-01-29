# Copyright 2017 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

GH_RN="github"
GH_REF="v${PV}"

# EXPORT_FUNCTIONS: src_unpack
inherit git-hosting

DESCRIPTION="Highly efficient cross-platform WebSocket & HTTP library for C++11 and Node.js"
LICENSE="ZLIB"

SLOT="0"

KEYWORDS="~amd64 ~arm ~arm64"
IUSE_A=( doc )

CDEPEND_A=(
	"dev-libs/libuv:0"
	"dev-libs/openssl:0"
	"sys-libs/zlib:0"
)
DEPEND_A=( "${CDEPEND_A[@]}" )
RDEPEND_A=( "${CDEPEND_A[@]}" )

inherit arrays

src_install() {
	emake PREFIX="${D}"/usr install
}
