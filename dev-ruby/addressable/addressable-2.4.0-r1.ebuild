# Copyright 2016 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

USE_RUBY="ruby20 ruby21"

inherit ruby-fakegem

DESCRIPTION="Addressable is a replacement for the URI implementation that is part of
Ruby'"
HOMEPAGE="https://github.com/sporkmonger/addressable"
LICENSE="Apache-2.0"

RESTRICT="mirror test"
SLOT="0"
KEYWORDS="~amd64 ~arm"

RUBY_FAKEGEM_EXTRAINSTALL='data'

## ebuild generated for gem `addressable-2.4.0` by gem2ebuild on 2016-04-07
