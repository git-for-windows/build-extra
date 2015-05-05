#!/bin/sh

# This script shows the download stats on GitHub. Update the id using the
# output of curl -s https://api.github.com/repos/git-for-windows/git/releases
# 2.3.4.windows.2
#id=${1:-1093748}
# 2.3.5.windows.4
#id=${1:-1130398}
# 2.3.5.windows.6
#id=${1:-1133929}
# 2.3.5.windows.7
#id=${1:-1147969}
# 2.3.5.windows.8
#id=${1:-1148462}
# 2.3.6.windows.2
#id=${1:-1215956}
# 2.3.7.msysgit.1
#id=${1:-1235013}
# 2.4.0.msysgit.1
id=${1:-1257687}

curl -s https://api.github.com/repos/git-for-windows/git/releases/$id/assets |
grep -e '"name":' -e '"download_count":'
