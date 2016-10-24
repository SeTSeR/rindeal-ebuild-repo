# Copyright 1999-2015 Gentoo Foundation
# Copyright 2016 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

GH_URI="github/i-rinat"
GH_REF="v${PV}"

inherit cmake-utils git-hosting

DESCRIPTION="VDPAU driver with OpenGL/VAAPI backend"
LICENSE="MIT"

SLOT="0"

KEYWORDS="~amd64"
IUSE="test"

RDEPEND="
	virtual/opengl
	x11-libs/libva[X]
	x11-libs/libvdpau
	x11-libs/libX11
	x11-libs/libXext
"
DEPEND="${RDEPEND}
	>=sys-apps/gawk-4.1
	virtual/pkgconfig"

src_prepare() {
	default

	# prevent cmake from using anything from here
	rm -vrf 3rdparty || die

	# add libvdpau deps
	gawk -i inplace '
		/pkg_check_modules/ {
			if ( ! pcm ) {
				print "pkg_check_modules(LIBVDPAU vdpau REQUIRED)"
				pcm=1
			}
		}
		/_INCLUDE_DIRS/ {
			if ( ! incdirs ) {
				print "${LIBVDPAU_INCLUDE_DIRS}"
				incdirs=1
			}
		}
		{ print; }
	' CMakeLists.txt || die
}

src_compile() {
	cmake-utils_src_compile
	use test && cmake-utils_src_make build-tests
}

# NOTE: tests require a running Xorg, but will fail in Xvfb

src_install() {
	cmake-utils_src_install

	newenvd <( cat<<-_EOF_
			# Automatically generated by ${CATEGORY}/${PF} on $(date --utc --iso-8601=minutes)
			VDPAU_DRIVER=va_gl
			_EOF_
		) 10${PN}
}

pkg_postinst() {
	elog 'To make this work you have to set env var `VDPAU_DRIVER=va_gl`'
	elog 'This package installed env.d file to set it for you automatically, but'
	elog 'you need to re-login to make use of it.'
}
