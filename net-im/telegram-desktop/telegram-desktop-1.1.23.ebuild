# Copyright 2016-2017 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

## git-hosting.eclass
GH_RN='github:rindeal:tgd-rindeal'
GH_REF="v${PV}"
if [[ -n "${TELEGRAM_DEBUG}" ]] ; then
	unset GH_REF
	GH_FETCH_TYPE="live"
	EGIT_BRANCH=dev
	EGIT_SUBMODULES=()
fi

## python-any-r1.eclass
PYTHON_COMPAT=( python2_7 )

## functions: best_version
inherit versionator
## functions: tgd-utils_get_QT_PREFIX, tgd-utils_get_qt_P
inherit telegram-desktop-utils
## EXPORT_FUNCTIONS: src_unpack
inherit git-hosting
## EXPORT_FUNCTIONS: src_prepare pkg_preinst pkg_postinst pkg_postrm
inherit xdg
## functions: make_desktop_entry, newicon
inherit eutils
inherit flag-o-matic
inherit qmake-utils
## functions: systemd_newuserunit
inherit systemd
## EXPORT_FUNCTIONS: pkg_setup
inherit python-any-r1
inherit gyp-utils

TG_PRETTY_NAME="Telegram Desktop"

DESCRIPTION='Official desktop client for the Telegram messenger, built from source'
HOMEPAGE="https://desktop.telegram.org/ ${HOMEPAGE}"
LICENSE='GPL-3' # with OpenSSL exception

SLOT='0'

declare -g -A SNAPSHOT_DISTFILES=()
my_set_snapshot_uris() {
	local rn ref snapshot_url snapshot_ext
	local -A downloads=(
		## tgd v1.1.23 was released on 2017.09.06

		["linux-syscall-support"]="gitlab:rindeal-mirrors:chromium-linux-syscall-support	a91633d172407f6c83dd69af11510b37afebb7f9"
	)
	local code
	for code in "${!downloads[@]}" ; do
		local payload_a=( ${downloads["${code}"]} )
		local rn="${payload_a[0]}"
		local ref="${payload_a[1]}"

		git-hosting_gen_snapshot_url "${rn}" "${ref}" snapshot_url snapshot_ext

		local distfile="${rn//:/--}--${ref}${snapshot_ext}" ; distfile="${distfile//'/'/_}"

		SNAPSHOT_DISTFILES+=( ["${code}"]="${distfile}" )

		SRC_URI+=$'\n'"${snapshot_url} -> ${distfile}"
	done
}
my_set_snapshot_uris

KEYWORDS="~amd64"
IUSE_A=( autostart_generic autostart_plasma_systemd gtk proxy )

CDEPEND_A=(
	# Telegram requires shiny new versions since v0.10.1 and commit
	# https://github.com/telegramdesktop/tdesktop/commit/27cf45e1a97ff77cc56a9152b09423b50037cc50
	# list of required USE flags is taken from `.travis/build.sh`
	'>=media-video/ffmpeg-3.1:0=[mp3,opus,vorbis,wavpack]'	# 'libav*', 'libsw*'
	'>=media-libs/openal-1.17.2'	# 'openal', '<AL/*.h>'
	'dev-libs/openssl:0'
	'sys-libs/zlib[minizip]'		# replaces the bundled copy in 'Telegram/ThirdParty/minizip/'

	## X libs are taken from 'Telegram/Telegram.pro'
	'x11-libs/libXext'
	'x11-libs/libXi'
	'x11-libs/libxkbcommon'
	'x11-libs/libX11'

	# Indirect dep. Older versions cause issues through
	# 'qt-telegram-static' -> 'qtimageformats' -> 'libwebp' chain.
	# https://github.com/rindeal/gentoo-overlay/issues/123
	'>=media-libs/libwebp-0.4.2'
)
DEPEND_A=( "${CDEPEND_A[@]}"
	'=dev-qt/qt-telegram-static-5.6.2*'
	"${PYTHON_DEPS}"

	## CXXFLAGS pkg-config from 'Telegram/Telegram.pro'
	'dev-libs/libappindicator:2'
	'dev-libs/glib:2'
	'x11-libs/gtk+:2'

	'virtual/pkgconfig'
)
RDEPEND_A=( "${CDEPEND_A[@]}"
	# block some alternative names and binary packages
	'!net-im/telegram'{,-bin}
	'!net-im/telegram-desktop-bin'
)

REQUIRED_USE_A=(
	'?? ( autostart_generic autostart_plasma_systemd )'
)

inherit arrays

RESTRICT+=' test'

L10N_LOCALES=( de es it ko nl pt_BR )
inherit l10n-r1

CHECKREQS_DISK_BUILD='1G'
inherit check-reqs

TG_DIR="${S}/Telegram"
TG_PRO="${TG_DIR}/Telegram.pro"
TG_INST_BIN="/usr/bin/${PN}"
TG_SHARED_DIR="/usr/share/${PN}"
TG_AUTOSTART_ARGS=( -startintray )
TG_GYP_DIR="${TG_DIR}/gyp"

# override qt5 path for use with eqmake5
qt5_get_bindir() { echo "${QT5_PREFIX}/bin" ; }

pkg_setup() {
	if use autostart_generic || use autostart_plasma_systemd ; then
		[[ -z "${TELEGRAM_AUTOSTART_USERS}" ]] && \
			die "You have enabled autostart_* USE flag, but haven't set TELEGRAM_AUTOSTART_USERS variable"
		for u in ${TELEGRAM_AUTOSTART_USERS} ; do
			id -u "${u}" >/dev/null || die "Invalid username '${u}' in TELEGRAM_AUTOSTART_USERS"
		done
	fi

	python-any-r1_pkg_setup
}

src_unpack() {
	git-hosting_src_unpack

	local code
	for code in "${!SNAPSHOT_DISTFILES[@]}" ; do
		git-hosting_unpack "${DISTDIR}/${SNAPSHOT_DISTFILES["${code}"]}" "${WORKDIR}/${code}"
	done
}

src_prepare-locales() {
	local l locales dir='Resources/langs' pre='lang_' post='.strings'

	l10n_find_changes_in_dir "${dir}" "${pre}" "${post}"

	l10n_get_locales locales app off
	for l in ${locales} ; do
		erm "${dir}/${pre}${l}${post}"
		sed -r -e "s|^(.*${pre}${l}${post}.*)|<!-- locales \1 -->|" \
			-i -- 'Resources/qrc/telegram.qrc' || die
		sed -r -e "s|('${l//_/-}',)|# locales # \1|" \
			-i -- "gyp/Telegram.gyp" || die
		sed -r -e "s#${l}(,|$)##" \
			-i -- "Resources/langs/list" || die
	done
}

src_prepare-delete_and_modify() {
	local args

	## patch "${TG_PRO}"
	args=(
		# delete any hardcoded libs
		-e 's|^(.*LIBS *\+= *-l.*)|# hardcoded libs # \1|'
		# delete refs to bundled Google Breakpad
		-e 's|^(.*/breakpad.*)|# Google Breakpad # \1|'
		# delete refs to bundled minizip, Gentoo uses it's own patched version
		-e 's|^(.*/minizip.*)|# minizip # \1|'
		# delete CUSTOM_API_ID defines, use default ID
		-e 's|^(.*CUSTOM_API_ID.*)|# CUSTOM_API_ID # \1|'
		# remove hardcoded flags, but do not remove `$$PKG_CONFIG ...` appends
		-e 's|^(.*QMAKE_[A-Z]*FLAGS(_[A-Z]*)* *.= *-.*)|# hardcoded flags # \1|'
		# use release versions
		-e 's:(.*)Debug(Style|Lang)(.*):\1Release\2\3 # Debug -> Release Style/Lang:g'
		-e 's|(.*)/Debug(.*)|\1/Release\2 # Debug -> Release|g'
		# dee is not used
		-e 's|^(.*dee-1.0.*)|# dee not used # \1|'
	)
# 	sed -r "${args[@]}" \
# 		-i -- "${TG_PRO}" || die

	## opus is used from inside of ffmpeg and not as a dedicated library
# 	sed -r -e 's|^(.*opus.*)|# opus lib is not used # \1|' -i -- "${TG_PRO}" || die
}

src_prepare-appends() {
	# make sure there is at least one empty line at the end before adding anything
	echo >> "${TG_PRO}"

	printf '%s\n\n' '# --- EBUILD APPENDS BELOW ---' >> "${TG_PRO}" || die

	## add corrected dependencies back
	local deps=(
		minizip # upstream uses bundled copy
	)
	local libs=( "${deps[@]}"
		xkbcommon # upstream links xkbcommon statically
	)
	local includes=( "${deps[@]}" )

	local l i
	for l in "${libs[@]}" ; do
		echo "PKGCONFIG += ${l}" >>"${TG_PRO}" || die
	done
	for i in "${includes[@]}" ; do
		printf 'QMAKE_CXXFLAGS += `%s %s`\n' '$$PKG_CONFIG --cflags-only-I' "${i}" >>"${TG_PRO}" || die
	done
}

src_prepare() {
# 	eapply "${FILESDIR}"/0.10.1-revert_Round_radius_increased_for_message_bubbles.patch

	xdg_src_prepare

	cd "${TG_DIR}" || die

	erm -r ThirdParty # prevent accidentically using something from there

	## determine which qt-telegram-static version should be used
	if [[ -z "${QT_TELEGRAM_STATIC_SLOT}" ]] ; then
		local qtstatic_PVR="$(best_version "$(tgd-utils_get_qt_P)" | sed "s|.*${qtstatic}-||")"
		local qtstatic_PV="${qtstatic_PVR%%-*}" # strip revision
		declare -g -- QT_VER="${qtstatic_PV%%_p*}"
		declare -g -- QT_PATCH_NUM="${qtstatic_PV##*_p}"
		declare -g -- QT_TELEGRAM_STATIC_SLOT="${QT_VER}-${QT_PATCH_NUM}"
	else
		einfo "Using QT_TELEGRAM_STATIC_SLOT from environment - '${QT_TELEGRAM_STATIC_SLOT}'"
		declare -g -- QT_VER="${QT_TELEGRAM_STATIC_SLOT%%-*}"
		declare -g -- QT_PATCH_NUM="${QT_TELEGRAM_STATIC_SLOT##*-}"
	fi

	tgd-utils_get_QT_PREFIX QT5_PREFIX "${QT_VER}" "${QT_PATCH_NUM}"
	[[ -e "${QT5_PREFIX}" ]] || die "QT5_PREFIX dir doesn't exist: '${QT5_PREFIX}'"

	readonly QT_TELEGRAM_STATIC_SLOT QT_VER  QT_PATCH_NUM QT5_PREFIX

	echo
	einfo "${P} is going to be linked with 'Qt ${QT_VER} (p${QT_PATCH_NUM})'"
	echo

	src_prepare-locales
	src_prepare-delete_and_modify
# 	src_prepare-appends
}

src_configure() {
	# care a little less about the unholy mess
	append-cxxflags '-Wno-unused-'{function,parameter,variable,but-set-variable}
	append-cxxflags '-Wno-switch'

	# prefer patched qt
	export PATH="$(qt5_get_bindir):${PATH}"

	# available since https://github.com/telegramdesktop/tdesktop/commit/562c5621f507d3e53e1634e798af56851db3d28e
	export QT_TDESKTOP_VERSION="${QT_VER}"
	export QT_TDESKTOP_PATH="${QT5_PREFIX}"

	GYP_DEFINES=(
		### `grep -r -Po --no-filename "TDESKTOP_\w+" | sort -u`

		## disable updater
		'TDESKTOP_DISABLE_AUTOUPDATE'

		## disable google-breakpad support
		'TDESKTOP_DISABLE_CRASH_REPORTS'

		## disable .desktop file runtime generation
		'TDESKTOP_DISABLE_DESKTOP_FILE_GENERATION'

		## remove all dependencies on GTK and appindicator
		# https://github.com/telegramdesktop/tdesktop/pull/3778
		$(usex gtk '' 'TDESKTOP_DISABLE_GTK_INTEGRATION')

		## proxy support
		# https://github.com/telegramdesktop/tdesktop/commit/0b2bcbc3e93a7fe62889abc66cc5726313170be7
		$(usex proxy '' 'TDESKTOP_DISABLE_NETWORK_PROXY')

		# disable registering `tg://` scheme in runtime
		'TDESKTOP_DISABLE_REGISTER_CUSTOM_SCHEME'

		## remove Unity support
		# https://github.com/telegramdesktop/tdesktop/pull/2200
		'TDESKTOP_DISABLE_UNITY_INTEGRATION'

		## not needed
		# 'TDESKTOP_MTPROTO_OLD'
	)

	cd "${TG_DIR}/gyp"

	local my_gyp_args=(
		-D PYTHON="${PYTHON}"

		-D build_defines="$(IFS=,; echo "${GYP_DEFINES[*]}")"
		-D linux_path_xkbcommon=$XKB_PATH
		-D linux_path_va=$VA_PATH
		-D linux_path_vdpau=$VDPAU_PATH
		-D linux_path_ffmpeg=$FFMPEG_PATH
		-D linux_path_openal=$OPENAL_PATH
		-D linux_path_qt=$QT_PATH
		-D linux_path_breakpad=$BREAKPAD_PATH
		-D linux_path_libexif_lib=/usr/local/lib
		-D linux_path_opus_include=/usr/include/opus
		-D linux_lib_ssl=-lssl
		-D linux_lib_crypto=-lcrypto
		-D linux_lib_icu="-licuuc -licutu -licui18n"

		--generator-output=..
		-G output_dir=../out
	)

	egyp "${my_gyp_args[@]}" Telegram.gyp
}

src_compile() {
	local d module

	## NOTE: directory naming follows upstream and is hardcoded in .pro files

	for module in style numbers ; do	# order of modules matters
		d="${S}/Linux/obj/codegen_${module}/Release"
		emkdir "${d}" && cd "${d}" || die

		elog "Building: ${PWD/${S}\/}"
		my_eqmake5 "${TG_DIR}/build/qmake/codegen_${module}/codegen_${module}.pro"
		emake
	done

	for module in Lang ; do		# order of modules matters
		d="${S}/Linux/ReleaseIntermediate${module}"
		emkdir "${d}" && cd "${d}" || die

		elog "Building: ${PWD/${S}\/}"
		my_eqmake5 "${TG_DIR}/Meta${module}.pro"
		emake
	done

	d="${S}/Linux/ReleaseIntermediate"
	emkdir "${d}" && cd "${d}" || die

	elog "Preparing the main build ..."
	elog "Note: ignore the warnings/errors below"
	# this qmake will fail to find "${TG_DIR}/GeneratedFiles/*", but it's required for ...
	my_eqmake5 "${TG_PRO}"
	# ... this make, which will generate those files
	local targets=( $( awk '/^PRE_TARGETDEPS *\+=/ { $1=$2=""; print }' "${TG_PRO}" ) )
	(( ${#targets[@]} )) || die
	emake ${targets[@]}

	# now we have everything we need, so let's begin!
	elog "Building Telegram ..."
	my_eqmake5 "${TG_PRO}"
	emake
}

my_pkgconfig_get_libs() {
	pkg-config --libs "${@}" | sed -e 's|-l||'
}

src_compile() {
  cd "$UPSTREAM/out/Debug"

  export ASM="gcc"
  cmake .
  make $MAKE_ARGS
}

# ### BEGIN: generated files

TG_SYSTEMD_SERVICE_NAME="${PN}"

my_install_systemd_service() {
	local tmpfile="$(mktemp)"
	cat <<-_EOF_ > "${tmpfile}" || die
		# $(print_generated_file_header)
		[Unit]
		Description=${TG_PRETTY_NAME} messaging app
		# standard targets are not available in user mode, so no deps can be specified


		[Service]
		ExecStartPre=/bin/sh -c "[ -n \"${DISPLAY}\" ]"
		# list of all cmdline options is in 'Telegram/SourceFiles/settings.cpp'
		ExecStart="${EPREFIX}${TG_INST_BIN}" "${TG_AUTOSTART_ARGS[@]}"
		Restart=on-failure
		RestartSec=1min


		# no "Install" section as this service can only be started manually or via a script
		# systemd
	_EOF_
	systemd_newuserunit "${tmpfile}" "${TG_SYSTEMD_SERVICE_NAME}.service"
}

my_install_autostart_sh() {
	local tmpfile="$(mktemp)"
	cat <<-_EOF_ > "${tmpfile}" || die
		#!/bin/sh
		# $(print_generated_file_header)
		'${EPREFIX}/usr/bin/systemctl' --user start '${TG_SYSTEMD_SERVICE_NAME}.service'
	_EOF_
	insinto "${TG_SHARED_DIR}"/autostart-scripts
	newins "${tmpfile}" "10-${PN}.sh"
}

my_install_shutdown_sh() {
	local tmpfile="$(mktemp)"
	cat <<-_EOF_ > "${tmpfile}" || die
		#!/bin/sh
		# $(print_generated_file_header)
		'${EPREFIX}/usr/bin/systemctl' --user stop '${TG_SYSTEMD_SERVICE_NAME}.service'
	_EOF_
	insinto "${TG_SHARED_DIR}"/shutdown
	newins "${tmpfile}" "10-${PN}.sh"
}

my_install_autostart_desktop() {
	local tmpfile="$(mktemp)"
	cat <<-_EOF_ > "${tmpfile}" || die
		# $(print_generated_file_header)
		[Desktop Entry]
		Version=1.0

		Name=${TG_PRETTY_NAME}
		Type=Application

		Exec="${EPREFIX}${TG_INST_BIN}" "${TG_AUTOSTART_ARGS[@]}"
		Terminal=false
	_EOF_
	insinto "${TG_SHARED_DIR}"/autostart
	newins "${tmpfile}" "${PN}.desktop"
}

my_install_autostart_howto() {
	local tmpfile="$(mktemp)"
	cat <<-_EOF_ > "${tmpfile}" || die
		You can set it up either automatically using Portage or manually.

		Automatically
		--------------
		Enable one of autostart_* USE flags for ${CATEGORY}/${PN} package and
		set TELEGRAM_AUTOSTART_USERS variable in make.conf to a space-separated list
		of user names for which you'd like to set it up.

		Manually
		---------

		If you have KDE Plasma + systemd:

		\`\`\`
		cp -v "${EPREFIX}${TG_SHARED_DIR}"/autostart-scripts/* ~/.config/autostart-scripts/
		cp -v "${EPREFIX}${TG_SHARED_DIR}"/shutdown/* ~/.config/plasma-workspace/shutdown/
		\`\`\`

		otherwise:

		\`\`\`
		cp -v "${EPREFIX}${TG_SHARED_DIR}"/autostart/* ~/.config/autostart/
		\`\`\`
	_EOF_
	insinto "${TG_SHARED_DIR}"
	newins "${tmpfile}" autostart-howto.txt
}

# END: generated files

src_install() {
	newbin "${S}/Linux/Release/Telegram" "${TG_INST_BIN##*/}"

	### docs
	einstalldocs

	### icons
	local s
	for s in 16 32 48 64 128 256 512 ; do
		newicon -s ${s} "${TG_DIR}/Resources/art/icon${s}.png" "${PN}.png"
	done

	### .desktop entry -- upstream version at 'lib/xdg/telegramdesktop.desktop'
	local make_desktop_entry_args
	make_desktop_entry_args=(
		"${EPREFIX}${TG_INST_BIN} -- %u"	# exec
		"${TG_PRETTY_NAME}"		# name
		"${TG_INST_BIN##*/}"	# icon
		'Network;InstantMessaging;Chat;Qt'	# categories
	)
	make_desktop_entry_extras=(
		'MimeType=x-scheme-handler/tg;'
		'StartupWMClass=TelegramDesktop'	# this should follow upstream
	)
	make_desktop_entry "${make_desktop_entry_args[@]}" \
		"$( printf '%s\n' "${make_desktop_entry_extras[@]}" )"

	### systemd
	my_install_systemd_service

	### autostart -- plasma + systemd
	my_install_autostart_sh
	my_install_shutdown_sh
	if use autostart_plasma_systemd ; then
		local u
		for u in ${TELEGRAM_AUTOSTART_USERS} ; do
			local homedir="$(eval "echo ~${u}")"

			install -v --owner="${u}" --mode=700 \
				-D --target-directory="${D}/${homedir}"/.config/autostart-scripts/ \
				-- "${ED}"/${TG_SHARED_DIR}/autostart-scripts/* || die
			install -v --owner="${u}" --mode=700 \
				-D --target-directory="${D}/${homedir}"/.config/plasma-workspace/shutdown/ \
				-- "${ED}"/${TG_SHARED_DIR}/shutdown/* || die
		done
	fi

	### autostart -- other DEs
	my_install_autostart_desktop
	if use autostart_generic ; then
		local u
		for u in ${TELEGRAM_AUTOSTART_USERS} ; do
			local homedir="$(eval "echo ~${u}")"

			install -v --owner="${u}" --mode=600 \
				-D --target-directory="${D}/${homedir}"/.config/autostart/ \
				-- "${ED}"/${TG_SHARED_DIR}/autostart/* || die
		done
	fi

	### autostart -- tutorial
	my_install_autostart_howto
}
