curl -s https://ispip.clang.cn/all_cn.txt | sed -e 's/^/add address=/g' -e 's/$/ list=CNIP_List/g' >1.rsc
curl -s https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt | sed -e 's/^/add address=/g' -e 's/$/ list=CNIP_List/g' >2.rsc
curl -s https://raw.githubusercontent.com/metowolf/iplist/master/data/special/china.txt | sed -e 's/^/add address=/g' -e 's/$/ list=CNIP_List/g' >3.rsc
sort -u 1.rsc 2.rsc 3.rsc | sed -e '1i/ip firewall address-list \nremove [/ip firewall address-list find list=CNIP_List]' >CNIP_List.RSC
rm -rf *.rsc
