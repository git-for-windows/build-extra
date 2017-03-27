#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

for URL
do
	case "$URL" in
	http://mid.gmane.org/*|https://mid.gmane.org/*)
		URL=https://public-inbox.org/git/"${URL#*org/}"/raw
		;;
	http://article.gmane.org/*[0-9]/raw|http://article.gmane.org/*[0-9]|http://article.gmane.org/*[0-9]/|http://permalink.gmane.org/*[0-9]/raw|http://permalink.gmane.org/*[0-9]|http://permalink.gmane.org/*[0-9]/|http://thread.gmane.org/*[0-9]|http://thread.gmane.org/*[0-9]/)
		GID=${URL%/raw}
		GID=${GID%/}
		GID=${GID##*/}
		test -z "$(echo "$GID" | tr -d 0-9)" ||
		die "Invalid GMane ID: $GID"
		HTML="$(git rev-parse --git-path public-inbox.html)"
		curl -s https://public-inbox.org/git/?q=gmane%3A$GID >"$HTML"
		grep "Results 1-1 of 1" "$HTML" ||
		die "No match, or ambiguous GMane ID: $GID"
		URL="$(sed -n '/^1\./{N;s/.*href="\([^"]*\).*/\1/p}' <"$HTML")"
		test -n "$URL" || die "Could not extract URL for GMane ID $GID"
		URL=https://public-inbox.org/git/${URL%/}/raw
		;;
	http*)
		;; # okay
	*@*)
		# Message-ID:
		URL=https://public-inbox.org/git/"$URL"/raw
		;;
	esac

	case "$URL" in
	*/raw)
		# already raw
		;;
	*/t)
		# thread view
		URL=${URL%t}raw
		;;
	*)
		URL=${URL%/}/raw
		;;
	esac

	OUT="$(git rev-parse --git-path public-inbox)"
	curl -f -o "$OUT" $URL ||
	die "Could not retrieve $URL" >&2

	if grep '\[PATCH.* 00*/[1-9]' "$OUT"
	then
		echo "Multi-part: $OUT $URL" >&2
		OUT2="$OUT.coverletter.html"
		OUT3="$OUT.mbox"
		curl -s "${URL%raw}" >"$OUT2" ||
		die "Could not retrieve cover letter from ${URL%raw}" >&2

		rm -f "$OUT3"
		NO=1
		while true
		do
			URL3="$(sed -n '/.*\[PATCH.* 0*'$NO'\/[1-9]/{
					s/^href="\.\.\/\([^"]*\).*/\1/p;q
				}' <"$OUT2")"
			test -n "$URL3" || break
			curl -f https://public-inbox.org/git/${URL3%/}/raw \
				>>"$OUT3" ||
			die "Could not retrieve $URL3" >&2
			NO=$(($NO+1))
		done
		git am --whitespace=fix -3 -s <"$OUT3" || break
	else
		git am --whitespace=fix -3 -s <"$OUT" || break
	fi
done
