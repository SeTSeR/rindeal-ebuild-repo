# Copyright 1999-2016 Gentoo Foundation
# Copyright 2016-2017 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

LT_SONAME='8'

inherit libtorrent-rasterbar

PATCHES=(
	"${FILESDIR}"/1.0.11-boost_1_65.patch
)
