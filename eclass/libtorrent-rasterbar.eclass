# Copyright 2016-2017 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

if [ -z "${LT_RASTERBAR_ECLASS}" ] ; then

case "${EAPI:-0}" in
	6) ;;
	*) die "Unsupported EAPI='${EAPI}' for '${ECLASS}'" ;;
esac

inherit rindeal


[[ -z "${PYTHON_COMPAT}" ]] && \
	PYTHON_COMPAT=( python2_7 python3_{4,5,6} )
[[ -z "${PYTHON_REQ_USE}" ]] && \
	PYTHON_REQ_USE="threads"

[[ -z "${DISTUTILS_OPTIONAL}" ]] && \
	DISTUTILS_OPTIONAL=true
[[ -z "${DISTUTILS_IN_SOURCE_BUILD}" ]] && \
	DISTUTILS_IN_SOURCE_BUILD=true

GH_RN='github:arvidn:libtorrent'
GH_FETCH_TYPE='manual'


## functions: prune_libtool_files()
inherit eutils
## EXPORT_FUNCTIONS: src_unpack
inherit vcs-snapshot
## EXPORT_FUNCTIONS: src_unpack
inherit git-hosting
## EXPORT_FUNCTIONS: src_prepare src_configure src_compile src_test src_install
inherit distutils-r1
## functions: version_compare
inherit versionator
## functions: make_setup.py_extension_compilation_parallel
inherit rindeal-python-utils


DESCRIPTION='C++ BitTorrent implementation focusing on efficiency and scalability'
HOMEPAGE="http://libtorrent.org ${GH_HOMEPAGE}"
LICENSE='BSD'


[[ -z "${LT_SONAME}" ]] && die "LT_SONAME not defined or empty"
SLOT="0/${LT_SONAME}"
# prepared tarball saves eautoreconf() call. Repo snapshot is not needed for now.
SRC_URI="${GH_REPO_URL}/releases/download/libtorrent-${PV//./_}/${P}.tar.gz"


[[ "${PV}" != *9999* ]] && [[ -z "${KEYWORDS}" ]] && \
	KEYWORDS='~amd64 ~arm ~arm64'
IUSE_A=( +crypt debug +dht doc examples python static-libs test )


CDEPEND_A=(
	"!!net-libs/rb_libtorrent"
	"dev-libs/boost:=[threads]"
	"virtual/libiconv"

	"crypt? ( dev-libs/openssl:0= )"
	"examples? ( !net-p2p/mldonkey )"
	"python? ( ${PYTHON_DEPS}"
		"dev-libs/boost:=[python,${PYTHON_USEDEP}]"
	")"
)
DEPEND_A=( "${CDEPEND_A[@]}"
	"sys-devel/libtool"
)

REQUIRED_USE_A=( "python? ( ${PYTHON_REQUIRED_USE} )" )
RESTRICT+=" mirror test"

inherit arrays


EXPORT_FUNCTIONS src_unpack src_prepare src_configure src_compile src_install


libtorrent-rasterbar_src_unpack() {
	vcs-snapshot_src_unpack
}

libtorrent-rasterbar_src_prepare() {
	default

	# https://github.com/rindeal/gentoo-overlay/issues/28
	# make sure lib search dir points to the main `S` dir and not to python copies
	sed -e "s|-L[^ ]*/src/\.libs|-L${S}/src/.libs|" \
		-i -- bindings/python/link_flags.in || die

	# respect optimization flags
	sed -e '/DEBUGFLAGS *=/ s|-O[a-z0-9]||' \
		-i -- configure.ac || die

	make_setup.py_extension_compilation_parallel bindings/python/setup.py

	use python && distutils-r1_src_prepare
}

libtorrent-rasterbar_src_configure() {
	local my_econf_args=(
		--disable-silent-rules # gentoo#441842
		# hardcode boost system to skip "lookup heuristic"
		--with-boost-system='mt'
		--with-libiconv

		$(use_enable crypt encryption)
		$(use_enable debug)
		$(use_enable debug disk-stats)
		$(use_enable debug logging verbose)
		$(use_enable dht dht $(usex debug logging yes))
		$(use_enable examples)
		$(use_enable static-libs static)
		$(use_enable test tests)
	)

	if (( $(version_compare "${PV}" 1.1.0 ) == 1 )) ; then
		my_econf_args+=( $(use_enable debug statistics) )
	fi

	econf "${my_econf_args[@]}"

	if use python ; then
		python_configure() {
			local my_econf_args=( "${my_econf_args[@]}"
				--enable-python-binding
				--with-boost-python
			)
			econf "${my_econf_args[@]}"
		}
		distutils-r1_src_configure
	fi
}

libtorrent-rasterbar_src_compile() {
	default

	if use python ; then
		python_compile() {
			cd "${BUILD_DIR}"/../bindings/python || die
			distutils-r1_python_compile
		}
		distutils-r1_src_compile
	fi
}

libtorrent-rasterbar_src_install() {
	use doc && local HTML_DOCS+=( ./docs )

	default

	if use python ; then
		python_install() {
			cd "${BUILD_DIR}"/../bindings/python || die
			distutils-r1_python_install
		}
		distutils-r1_src_install
	fi

	prune_libtool_files
}


LT_RASTERBAR_ECLASS=1
fi
