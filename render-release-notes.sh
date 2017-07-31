#!/bin/sh

usage () {
	cat<<EOF

Usage: $0 [--output <dir>] [--css <dir>] [--copy-css | --preview]

If this script is executed without specifying any arguments, ReleaseNotes.html
will be generated in the present working directory and the corresponding
ReleaseNotes.css stylesheet will be copied to the present working directory as
well.

    --output <dir>
        Use this argument to specify the output directory for the generated
        ReleaseNotes.html file. The default location is the present working
        directory.

    --css <dir>
        Specifies the directory portion of the CSS stylesheet path to render
        for the @href attribute of the <link /> element in the Release Notes
        HTML file. The specified path will be taken relative to the path
        specified for the --output argument. If a value is not provided for
        this option, the CSS path will default to the path provided for
        --output.

    --copy-css
        Instructs this script to also copy the CSS stylesheet to the directory
        specified by the --css argument (or if not specified, the directory
        specified by the --output argument).

        When rendering the release notes as part of an installer package, it is
        not necessary to copy the CSS stylesheet. The installer builders should
        ensure that the CSS stylesheet is installed to the appropriate location
        to allow for proper release notes styling when viewing them in a
        browser.

    --preview
        This option implies the usage of --copy-css. After generating
        ReleaseNotes.html, the script will open ReleaseNotes.html in your
        default web browser.

    EXAMPLE:
    ========

            $0 --output ~/ --css styles --copy-css

        In this example, the ReleaseNotes.html file will be rendered to the
        current user's home directory. The HTML file will be rendered to look
        for its CSS stylesheet at ~/styles. Due to --copy-css being specified,
        ReleaseNotes.css will be copied to ~/styles so that when viewing the
        release notes in a browser, the release notes are properly styled.
EOF
	exit
}

die () {
	echo "$*" >&2
	exit 1
}

render_release_notes () {
	(homepage=https://git-for-windows.github.io/ &&
		contribute=$homepage#contribute &&
		wiki=https://github.com/git-for-windows/git/wiki &&
		faq=$wiki/FAQ &&
		mailinglist=mailto:git@vger.kernel.org &&
		links="$(printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" \
		'<div class="links">' \
		'<ul>' \
		'<li><a href="'$homepage'">homepage</a></li>' \
		'<li><a href="'$faq'">faq</a></li>' \
		'<li><a href="'$contribute'">contribute</a></li>' \
		'<li><a href="'$contribute'">bugs</a></li>' \
		'<li><a href="'$mailinglist'">questions</a></li>' \
		'</ul>' \
		'</div>')" &&
		printf '%s\n%s\n%s\n%s %s\n%s %s\n%s\n%s\n%s\n%s\n' \
		'<!DOCTYPE html>' \
		'<html>' \
		'<head>' \
		'<meta http-equiv="Content-Type" content="text/html;' \
		'charset=UTF-8">' \
		'<link rel="stylesheet"' \
		'href="'$CSSDIR${CSSDIR:+/}'ReleaseNotes.css">' \
		'</head>' \
		'<body class="details">' \
		"$links" \
		'<div class="content">'
		markdown "$SCRIPT_PATH"/ReleaseNotes.md ||
		die "Could not generate ReleaseNotes.html"
		printf '</div>\n</body>\n</html>\n') >"$OUTPUTDIR${OUTPUTDIR:+/}ReleaseNotes.html"
}

COPYCSS=
PREVIEW=

test $# -eq 0 && COPYCSS=1 || {
	while test $# -gt 0
	do
		case "$1" in
		--copy-css)
			COPYCSS=1
			;;
		--css)
			shift
			CSSDIR="${1%/}"
			;;
		--output)
			shift
			OUTPUTDIR="${1%/}"
			;;
		--preview|-p)
			PREVIEW=1
			COPYCSS=1
			;;
		--help|*)
			usage
			;;
		esac
		shift
	done
}

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Generate the ReleaseNotes.html file
test -x /usr/bin/markdown ||
export PATH="$PATH:$(readlink -f "$SCRIPT_PATH")/../../bin"

# Install markdown
type markdown ||
pacman -Sy --noconfirm markdown ||
die "Could not install markdown"

test -f "$OUTPUTDIR${OUTPUTDIR:+/}Release.html" &&
test "$OUTPUTDIR${OUTPUTDIR:+/}Release.html" -nt "$SCRIPT_PATH"/ReleaseNotes.md &&
test "$OUTPUTDIR${OUTPUTDIR:+/}Release.html" -nt "$SCRIPT_PATH"/render-release-notes.sh || {
	render_release_notes || die "Could not render $OUTPUTDIR${OUTPUTDIR:+/}ReleaseNotes.html"
	test -z "$COPYCSS" || {
		test -z "$CSSDIR" && CSSDIR="$OUTPUTDIR" || CSSDIR="$OUTPUTDIR${OUTPUTDIR:+/}$CSSDIR"
		test -z "$CSSDIR" || test -d "$CSSDIR" || mkdir -p "$CSSDIR"
		cp -u "$SCRIPT_PATH"/ReleaseNotes.css "$CSSDIR${CSSDIR:+/}ReleaseNotes.css"
	}
}

test -z "$PREVIEW" || start "$OUTPUTDIR${OUTPUTDIR:+/}ReleaseNotes.html"
