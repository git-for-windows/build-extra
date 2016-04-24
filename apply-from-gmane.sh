#!/bin/sh

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

	curl $URL | git am --whitespace=fix -3 -s || break
done
