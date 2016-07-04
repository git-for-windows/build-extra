#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

for URL
do
	case "$URL" in
	http://mid.gmane.org*)
		TMP=.git/apply.tmp
		curl -D $TMP "$URL" > /dev/null
		URL=$(sed -n 's/^Location: //p' < $TMP | tr -d '\r\n')
		;;
	http://thread.*)
		URL=http://article.${URL#http://thread.}
		;;
	http://permalink.gmane.org*)
		URL=http://article.${URL#http://permalink.}
		;;
	http://*|article.gmane.org*)
		# do nothing
		;;
	*@*)
		TMP=.git/apply.tmp
		curl -D $TMP http://mid.gmane.org/$1 > /dev/null
		URL=$(sed -n 's/^Location: //p' < $TMP | tr -d '\r\n')
		;;
	*)
		URL=http://article.gmane.org/gmane.comp.version-control.git/$URL
		;;
	esac

	case "$URL" in
	*/raw)
		# already raw
		;;
	*)
		URL=${URL%/}/raw
		;;
	esac

	OUT="$(git rev-parse --git-dir)"/gmane
	curl -f -o "$OUT" $URL ||
	die "Could not retrieve $URL" >&2

	if grep '\[PATCH.* 00*/[1-9]' "$OUT"
	then
		echo "Multi-part: $OUT $URL" >&2
		GROUP=${URL%/raw}
		THREAD=${GROUP##*/}
		GROUP=${GROUP%/$THREAD}
		GROUP=${GROUP##*/}
		URL2=http://news.gmane.org/group/$GROUP/thread=$THREAD
		OUT2="$OUT.coverletter.html"
		curl -f -o "$OUT2" "$URL2" ||
		die "Could not retrieve cover letter from $URL2" >&2

		NO=1
		while true
		do
			URL3="$(sed -n '/.*\[PATCH.* 0*'$NO'\/[1-9]/{
					s/.*\(http:\/\/article[^\"]*\).*/\1/p;q
				}' <"$OUT2")"
			test -n "$URL3" || break
			OUT3="$OUT.$NO"
			curl -f -o "$OUT3" $URL3/raw ||
			die "Could not retrieve $URL3" >&2
			git am --whitespace=fix -3 -s <"$OUT3" || break
			NO=$(($NO+1))
		done
	else
		git am --whitespace=fix -3 -s <"$OUT" || break
	fi
done
