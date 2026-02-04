curl -s https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMaxNoIP/ChinaMaxNoIP_Domain.txt | sed -e '/^#/d' -e 's/^\.//' -e '/.*\.[a-zA-Z].*/!d' > chinamax.txt
curl -s https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf | sed -e 's|^server=/\(.*\)/114.114.114.114$|\1|' | grep -Ev -e '^#' -e '^$' > china.txt
curl -s https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf | sed -e 's|^server=/\(.*\)/114.114.114.114$|\1|' | grep -Ev -e '^#' -e '^$' > apple.txt
cat chinamax.txt china.txt apple.txt ./Scripts/IncludeCNDomains | grep -vFf ./Scripts/ExcludeCNDomains | sort -u > all.txt
sed -e 's/^/add forward-to=$dnsserver type=FWD address-list=CNDomain_List match-subdomain=yes name=/g' -e '1i:local dnsserver 223.5.5.5\n/ip dns static\nremove [/ip dns static find address-list=CNDomain_List]' -e '$a/ip dns cache flush' all.txt >CNDomain_List.RSC
sed -e 's/^/[\//g' -e 's/$/\/]tls:\/\/223.5.5.5 tls:\/\/dot.pub/g' -e '1i10.0.0.254' all.txt > ADGRULES.TXT
rm -rf *.txt
