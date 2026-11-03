set -euo pipefail

ROS_DNS_NOTCN='10.0.0.9'
IGNORE_PATTERN='^!|\[|^@@|(https?://){0,1}[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
HEAD_FILTER_PATTERN='s#^(\|\|?)?(https?://)?##g'
TAIL_FILTER_PATTERN='s#/.*$|%2F.*$##g'
DOMAIN_PATTERN='([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)'
HANDLE_WILDCARD_PATTERN='s#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*[a-zA-Z0-9]*)?#\4#g'

{
    printf '%s\n' \
        '/ip dns forwarders' \
        'remove [find name=DNS_!CN]' \
        "add dns-servers=${ROS_DNS_NOTCN} name=DNS_!CN" \
        '/ip dns static' \
        'remove [find address-list=GFW_List]'

    curl -fsSL 'https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt' |
    base64 -d |
    grep -vE "$IGNORE_PATTERN" |
    sed -E "$HEAD_FILTER_PATTERN" |
    sed -E "$TAIL_FILTER_PATTERN" |
    grep -E "$DOMAIN_PATTERN" |
    sed -E "$HANDLE_WILDCARD_PATTERN" |
    sort -u |
    sed 's|^|add forward-to=DNS_!CN type=FWD address-list=GFW_List match-subdomain=yes name=|'

    printf '%s\n' '/ip dns cache flush'
} > DNS_Static_GFW.RSC
