set -euo pipefail

TMP_CN=$(mktemp)
trap 'rm -f "$TMP_CN"' EXIT

curl -fsSL 'https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/meta/geo/geoip/cn.list' >"$TMP_CN"

{
    printf '%s\n' '/ip firewall address-list' 'remove [find list=CNIP_List]'
    {
        for URL in \
            'https://ispip.clang.cn/all_cn.txt' \
            'https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt' \
            'https://raw.githubusercontent.com/metowolf/iplist/master/data/special/china.txt'; do
            curl -fsSL "$URL" |
                awk 'NF && $0 !~ /^[[:space:]]*#/ && index($0,":")==0 {gsub(/\r/,""); print "add address="$0" list=CNIP_List"}'
        done

        awk 'NF && $0 !~ /^[[:space:]]*#/ && index($0,":")==0 {gsub(/\r/,""); print "add address="$0" list=CNIP_List"}' "$TMP_CN"
    } | sort -u
} >CNIP_List.RSC

{
    printf '%s\n' '/ipv6 firewall address-list' 'remove [find list=CNIP_V6_List]'
    awk 'NF && $0 !~ /^[[:space:]]*#/ && index($0,":")>0 {gsub(/\r/,""); print "add address="$0" list=CNIP_V6_List"}' "$TMP_CN" | sort -u
} >CNIP_V6_List.RSC
