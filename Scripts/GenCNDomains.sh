curl -s https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_Domain.txt | sed -e '/^#/d' -e 's/^\.//' -e '/.*\.[a-zA-Z].*/!d' > chinamax.txt
curl -s https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf | sed -e 's|^server=/\(.*\)/114.114.114.114$|\1|' | grep -Ev -e '^#' -e '^$' > china.txt
curl -s https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf | sed -e 's|^server=/\(.*\)/114.114.114.114$|\1|' | grep -Ev -e '^#' -e '^$' > google.txt
curl -s https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf | sed -e 's|^server=/\(.*\)/114.114.114.114$|\1|' | grep -Ev -e '^#' -e '^$' > apple.txt
sort -u chinamax.txt china.txt apple.txt google.txt > all.txt
sed -e 's/^/add forward-to=$dnsserver type=FWD address-list=CNDomains match-subdomain=yes name=/g' -e '1i:local dnsserver 223.5.5.5\n/ip dns static\nremove [/ip dns static find address-list=CNDomains]' -e '$a/ip dns cache flush' all.txt >CNDOMAINS.RSC
sed -e 's/^/[\//g' -e 's/$/\/]h3:\/\/223.5.5.5\/dns-query https:\/\/1.12.12.12\/dns-query/g' -e '1i10.0.0.253' all.txt > ADGRULES.TXT
rm -rf *.txt
