# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Flatcar: Based on sqlite-3.32.3-r1.ebuild from commit
# 2dd8e3dd024c3a65b9117e2cd4f2f6ef7526dec7 in gentoo repo.

EAPI="7"

inherit autotools flag-o-matic multilib-minimal toolchain-funcs

if [[ "${PV}" != "9999" ]]; then
	SRC_PV="$(printf "%u%02u%02u%02u" $(ver_rs 1- " "))"
	DOC_PV="${SRC_PV}"
	# DOC_PV="$(printf "%u%02u%02u00" $(ver_rs 1-3 " "))"
fi

DESCRIPTION="SQL database engine"
HOMEPAGE="https://sqlite.org/"
if [[ "${PV}" == "9999" ]]; then
	SRC_URI=""
else
	# Flatcar: fetch different source tarballs according to USE flags.
	# full archive with suffix "-src" by defaults, and non-full archive with
	# suffix "-autoconf" in case of flags tcl, test, tools being disabled.
	SRC_URI="doc? ( https://sqlite.org/2020/${PN}-doc-${DOC_PV}.zip )
		tcl? ( https://sqlite.org/2020/${PN}-src-${SRC_PV}.zip )
		test? ( https://sqlite.org/2020/${PN}-src-${SRC_PV}.zip )
		tools? ( https://sqlite.org/2020/${PN}-src-${SRC_PV}.zip )
		!tcl? ( !test? ( !tools? ( https://sqlite.org/2020/${PN}-autoconf-${SRC_PV}.tar.gz ) ) )"
fi

LICENSE="public-domain"
SLOT="3"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~m68k ~mips ppc ppc64 ~riscv s390 sparc x86 ~ppc-aix ~x64-cygwin ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="debug doc icu +readline secure-delete static-libs tcl test tools"
if [[ "${PV}" == "9999" ]]; then
	PROPERTIES="live"
fi
RESTRICT="!test? ( test )"

if [[ "${PV}" == "9999" ]]; then
	BDEPEND=">=dev-lang/tcl-8.6:0
		dev-vcs/fossil"
else
	# Flatcar: disable dependency on dev-lang/tcl if tcl USE flag is disabled
	BDEPEND="app-arch/unzip
		tcl? ( >=dev-lang/tcl-8.6:0 )"
fi
RDEPEND="sys-libs/zlib:0=[${MULTILIB_USEDEP}]
	icu? ( dev-libs/icu:0=[${MULTILIB_USEDEP}] )
	readline? ( sys-libs/readline:0=[${MULTILIB_USEDEP}] )
	tcl? ( dev-lang/tcl:0=[${MULTILIB_USEDEP}] )
	tools? ( dev-lang/tcl:0=[${MULTILIB_USEDEP}] )"
DEPEND="${RDEPEND}
	test? ( >=dev-lang/tcl-8.6:0[${MULTILIB_USEDEP}] )"

full_archive() {
	[[ "${PV}" == "9999" ]] || use tcl || use test || use tools
}

# Flatcar: set up package on different source directory suffixes, "-src" for
# full archive and "-autoconf" for non-full archive.
pkg_setup() {
	if [[ "${PV}" == "9999" ]]; then
		S="${WORKDIR}/${PN}"
	else
		if full_archive; then
			S="${WORKDIR}/${PN}-src-${SRC_PV}"
		else
			S="${WORKDIR}/${PN}-autoconf-${SRC_PV}"
		fi
	fi
}

src_unpack() {
	if [[ "${PV}" == "9999" ]]; then
		local distdir="${PORTAGE_ACTUAL_DISTDIR:-${DISTDIR}}"
		addwrite "${distdir}"
		mkdir -p "${distdir}/fossil-src/${PN}" || die

		mkdir "${WORKDIR}/${PN}" || die
		pushd "${WORKDIR}/${PN}" > /dev/null || die
		if [[ ! -f "${distdir}/fossil-src/${PN}/sqlite.fossil" ]]; then
			einfo fossil clone --verbose https://sqlite.org/src sqlite.fossil
			fossil clone --verbose https://sqlite.org/src sqlite.fossil || die
			echo
		else
			cp -p "${distdir}/fossil-src/${PN}/sqlite.fossil" . || die
			einfo fossil pull --repository sqlite.fossil --verbose https://sqlite.org/src
			fossil pull --repository sqlite.fossil --verbose https://sqlite.org/src || die
			echo
		fi
		cp -p sqlite.fossil "${distdir}/fossil-src/${PN}" || die
		einfo fossil open --quiet sqlite.fossil
		fossil open --quiet sqlite.fossil || die
		echo
		popd > /dev/null || die

		if use doc; then
			mkdir "${WORKDIR}/${PN}-doc" || die
			pushd "${WORKDIR}/${PN}-doc" > /dev/null || die
			if [[ ! -f "${distdir}/fossil-src/${PN}/sqlite-doc.fossil" ]]; then
				einfo fossil clone --verbose https://sqlite.org/docsrc sqlite-doc.fossil
				fossil clone --verbose https://sqlite.org/docsrc sqlite-doc.fossil || die
				echo
			else
				cp -p "${distdir}/fossil-src/${PN}/sqlite-doc.fossil" . || die
				einfo fossil pull --repository sqlite-doc.fossil --verbose https://sqlite.org/docsrc
				fossil pull --repository sqlite-doc.fossil --verbose https://sqlite.org/docsrc || die
				echo
			fi
			cp -p sqlite-doc.fossil "${distdir}/fossil-src/${PN}" || die
			einfo fossil open --quiet sqlite-doc.fossil
			fossil open --quiet sqlite-doc.fossil || die
			echo
			popd > /dev/null || die
		fi
	else
		default
	fi
}

src_prepare() {
	# Flatcar: apply different patches, for full archive and non-full archive.
	if full_archive; then
		eapply "${FILESDIR}/"${PN}-3.32.1-full_archive-build_{1,2}.patch
		eapply "${FILESDIR}/"${PN}-3.32.3-full_archive-backports_{1,2,3}.patch
	else
		eapply "${FILESDIR}/"${PN}-3.32.3-nonfull_archive-build.patch
		eapply "${FILESDIR}/"${PN}-3.32.3-nonfull_archive-backports_{1,2,3}.patch
	fi

	eapply_user

	# Fix AC_CHECK_FUNCS.
	# https://mailinglists.sqlite.org/cgi-bin/mailman/private/sqlite-dev/2016-March/002762.html
	sed -e "s/AC_CHECK_FUNCS(.*)/AC_CHECK_FUNCS([fdatasync fullfsync gmtime_r isnan localtime_r localtime_s malloc_usable_size posix_fallocate pread pread64 pwrite pwrite64 strchrnul usleep utime])/" -i configure.ac || die "sed failed"

	eautoreconf

	multilib_copy_sources
}

multilib_src_configure() {
	local -x CPPFLAGS="${CPPFLAGS}" CFLAGS="${CFLAGS}"
	local options=()

	# Flatcar: apply config options, for full archive and non-full archive.
	options+=(
		--enable-$(full_archive && echo load-extension || echo dynamic-extensions)
		--enable-threadsafe
	)
	if ! full_archive; then
		options+=(--disable-static-shell)
	fi

	# Support detection of misuse of SQLite API.
	# https://sqlite.org/compile.html#enable_api_armor
	append-cppflags -DSQLITE_ENABLE_API_ARMOR

	# Support bytecode and tables_used virtual tables.
	# https://sqlite.org/bytecodevtab.html
	append-cppflags -DSQLITE_ENABLE_BYTECODE_VTAB

	# Support column metadata functions.
	# https://sqlite.org/c3ref/column_database_name.html
	append-cppflags -DSQLITE_ENABLE_COLUMN_METADATA

	# Support sqlite_dbpage virtual table.
	# https://sqlite.org/dbpage.html
	append-cppflags -DSQLITE_ENABLE_DBPAGE_VTAB

	# Support dbstat virtual table.
	# https://sqlite.org/dbstat.html
	append-cppflags -DSQLITE_ENABLE_DBSTAT_VTAB

	# Support sqlite3_serialize() and sqlite3_deserialize() functions.
	# https://sqlite.org/c3ref/serialize.html
	# https://sqlite.org/c3ref/deserialize.html
	append-cppflags -DSQLITE_ENABLE_DESERIALIZE

	# Support comments in output of EXPLAIN.
	# https://sqlite.org/compile.html#enable_explain_comments
	append-cppflags -DSQLITE_ENABLE_EXPLAIN_COMMENTS

	# Support Full-Text Search versions 3, 4 and 5.
	# https://sqlite.org/fts3.html
	# https://sqlite.org/fts5.html
	append-cppflags -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS4
	options+=(--enable-fts5)

	# Support hidden columns.
	append-cppflags -DSQLITE_ENABLE_HIDDEN_COLUMNS

	# Support JSON1 extension.
	# https://sqlite.org/json1.html
	append-cppflags -DSQLITE_ENABLE_JSON1

	# Support memsys5 memory allocator.
	# https://sqlite.org/malloc.html#memsys5
	append-cppflags -DSQLITE_ENABLE_MEMSYS5

	# Support sqlite3_normalized_sql() function.
	# https://sqlite.org/c3ref/expanded_sql.html
	append-cppflags -DSQLITE_ENABLE_NORMALIZE

	# Support sqlite_offset() function.
	# https://sqlite.org/lang_corefunc.html#sqlite_offset
	append-cppflags -DSQLITE_ENABLE_OFFSET_SQL_FUNC

	# Support pre-update hook functions.
	# https://sqlite.org/c3ref/preupdate_count.html
	append-cppflags -DSQLITE_ENABLE_PREUPDATE_HOOK

	# Support Resumable Bulk Update extension.
	# https://sqlite.org/rbu.html
	append-cppflags -DSQLITE_ENABLE_RBU

	# Support R*Trees.
	# https://sqlite.org/rtree.html
	# https://sqlite.org/geopoly.html
	append-cppflags -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_GEOPOLY

	# Support scan status functions.
	# https://sqlite.org/c3ref/stmt_scanstatus.html
	# https://sqlite.org/c3ref/stmt_scanstatus_reset.html
	append-cppflags -DSQLITE_ENABLE_STMT_SCANSTATUS

	# Support sqlite_stmt virtual table.
	# https://sqlite.org/stmt.html
	append-cppflags -DSQLITE_ENABLE_STMTVTAB

	# Support Session extension.
	# https://sqlite.org/sessionintro.html
	options+=(--enable-session)

	# Support unknown() function.
	# https://sqlite.org/compile.html#enable_unknown_sql_function
	append-cppflags -DSQLITE_ENABLE_UNKNOWN_SQL_FUNCTION

	# Support unlock notification.
	# https://sqlite.org/unlock_notify.html
	append-cppflags -DSQLITE_ENABLE_UNLOCK_NOTIFY

	# Support LIMIT and ORDER BY clauses on DELETE and UPDATE statements.
	# https://sqlite.org/lang_delete.html#optional_limit_and_order_by_clauses
	# https://sqlite.org/lang_update.html#optional_limit_and_order_by_clauses
	append-cppflags -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT

	# Support soundex() function.
	# https://sqlite.org/lang_corefunc.html#soundex
	append-cppflags -DSQLITE_SOUNDEX

	# Support URI filenames.
	# https://sqlite.org/uri.html
	append-cppflags -DSQLITE_USE_URI

	# debug USE flag.
	# Flatcar: enable different debug options, for full archive and non-full
	# archive.
	if full_archive; then
		options+=($(use_enable debug))
	else
		if use debug; then
			append-cppflags -DSQLITE_DEBUG
		else
			append-cppflags -DNDEBUG
		fi
	fi

	# icu USE flag.
	if use icu; then
		# Support ICU extension.
		# https://sqlite.org/compile.html#enable_icu
		append-cppflags -DSQLITE_ENABLE_ICU
		# Flatcar: set different ICU libs, for full archive and non-full.
		if full_archive; then
			sed -e "s/^TLIBS = @LIBS@/& -licui18n -licuuc/" -i Makefile.in || die "sed failed"
		else
			sed -e "s/^LIBS = @LIBS@/& -licui18n -licuuc/" -i Makefile.in || die "sed failed"
		fi
	fi

	# readline USE flag.
	options+=(
		--disable-editline
		$(use_enable readline)
	)
	# Flatcar: configure with bundled readline libs only for full archive.
	if full_archive && use readline; then
		options+=(--with-readline-inc="-I${ESYSROOT}/usr/include/readline")
	fi

	# secure-delete USE flag.
	if use secure-delete; then
		# Enable secure_delete pragma by default.
		# https://sqlite.org/pragma.html#pragma_secure_delete
		append-cppflags -DSQLITE_SECURE_DELETE
	fi

	# static-libs USE flag.
	options+=($(use_enable static-libs static))

	# tcl, test, tools USE flags.
	# Flatcar: enable tcl only if USE flag tcl turned on.
	if use tcl; then
		options+=(--enable-tcl)
	else
		options+=(--disable-tcl)
	fi

	if [[ "${CHOST}" == *-mint* ]]; then
		append-cppflags -DSQLITE_OMIT_WAL
	fi

	if [[ "${ABI}" == "x86" ]]; then
		if $(tc-getCC) ${CPPFLAGS} ${CFLAGS} -E -P -dM - < /dev/null 2> /dev/null | grep -q "^#define __SSE__ 1$"; then
			append-cflags -mfpmath=sse
		else
			append-cflags -ffloat-store
		fi
	fi

	econf "${options[@]}"
}

multilib_src_compile() {
	emake HAVE_TCL="$(usex tcl 1 "")" TCLLIBDIR="${EPREFIX}/usr/$(get_libdir)/${P}"

	if use tools && multilib_is_native_abi; then
		emake changeset dbdump dbhash dbtotxt index_usage rbu scrub showdb showjournal showshm showstat4 showwal sqldiff sqlite3_analyzer sqlite3_checker sqlite3_expert sqltclsh
	fi
}

multilib_src_test() {
	if [[ "${EUID}" -eq 0 ]]; then
		ewarn "Skipping tests due to root permissions"
		return
	fi

	local -x SQLITE_HISTORY="${T}/sqlite_history_${ABI}"

	emake HAVE_TCL="$(usex tcl 1 "")" $(use debug && echo fulltest || echo test)
}

multilib_src_install() {
	emake DESTDIR="${D}" HAVE_TCL="$(usex tcl 1 "")" TCLLIBDIR="${EPREFIX}/usr/$(get_libdir)/${P}" install

	if use tools && multilib_is_native_abi; then
		install_tool() {
			if [[ -f ".libs/${1}" ]]; then
				newbin ".libs/${1}" "${2}"
			else
				newbin "${1}" "${2}"
			fi
		}

		install_tool changeset sqlite3-changeset
		install_tool dbdump sqlite3-db-dump
		install_tool dbhash sqlite3-db-hash
		install_tool dbtotxt sqlite3-db-to-txt
		install_tool index_usage sqlite3-index-usage
		install_tool rbu sqlite3-rbu
		install_tool scrub sqlite3-scrub
		install_tool showdb sqlite3-show-db
		install_tool showjournal sqlite3-show-journal
		install_tool showshm sqlite3-show-shm
		install_tool showstat4 sqlite3-show-stat4
		install_tool showwal sqlite3-show-wal
		install_tool sqldiff sqlite3-diff
		install_tool sqlite3_analyzer sqlite3-analyzer
		install_tool sqlite3_checker sqlite3-checker
		install_tool sqlite3_expert sqlite3-expert
		install_tool sqltclsh sqlite3-tclsh

		unset -f install_tool
	fi
}

multilib_src_install_all() {
	find "${D}" -name "*.la" -type f -delete || die

	doman sqlite3.1

	if use doc; then
		rm "${WORKDIR}/${PN}-doc-${DOC_PV}/"*.{db,txt} || die
		(
			docinto html
			dodoc -r "${WORKDIR}/${PN}-doc-${DOC_PV}/"*
		)
	fi
}
