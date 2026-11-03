set -euo pipefail

DNS_NOTCN='10.0.0.9'
DNS_CN='tls://223.5.5.5 218.2.2.2'
ROS_DNS_NOTCN='10.0.0.9'
ROS_DNS_CN='223.5.5.5,218.2.2.2'

curl -fsSL 'https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/meta/geo/geosite/google.list' | sed -E '/^#/d; /^$/d; s/^\+\.//' >google.txt
curl -fsSL 'https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf' | sed -En 's|^server=/([^/]+)/114\.114\.114\.114$|\1|p' >china.txt
curl -fsSL 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMaxNoIP/ChinaMaxNoIP_Domain.txt' | sed -E '/^#/d; /^$/d; s/^\.//; /\.[a-zA-Z]/!d' >chinamax.txt
curl -fsSL 'https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf' | sed -En 's|^server=/([^/]+)/114\.114\.114\.114$|\1|p' >apple.txt

cat google.txt ./Scripts/ExcludeCNDomains | sort -u >'!cn.txt'
cat china.txt chinamax.txt apple.txt ./Scripts/IncludeCNDomains | sort -u >cn.txt

{
    printf '%s\n' '/ip dns forwarders' 'remove [find name=DNS_!CN]' "add dns-servers=${ROS_DNS_NOTCN} name=DNS_!CN" '/ip dns static' 'remove [find address-list=!CNDomain_List]'
    sed 's|^|add forward-to=DNS_!CN type=FWD address-list=!CNDomain_List match-subdomain=yes name=|' '!cn.txt'
    printf '%s\n' '/ip dns cache flush'
} >DNS_Static_Google.RSC
{
    printf '%s\n' '/ip dns forwarders' 'remove [find name=DNS_CN]' "add dns-servers=${ROS_DNS_CN} name=DNS_CN" '/ip dns static' 'remove [find address-list=CNDomain_List]'
    sed 's|^|add forward-to=DNS_CN type=FWD address-list=CNDomain_List match-subdomain=yes name=|' cn.txt
    printf '%s\n' '/ip dns cache flush'
} >DNS_Static_CNDomains.RSC

sed -E -e "1i${DNS_NOTCN}" -e "s|^(.*)$|[/\1/]${DNS_NOTCN}|" '!cn.txt' >'!cn_adgh.txt'
sed -E "s|^(.*)$|[/\1/]${DNS_CN}|" cn.txt >cn_adgh.txt
cat '!cn_adgh.txt' cn_adgh.txt >ADGHRULES.TXT
rm -f *.txt
