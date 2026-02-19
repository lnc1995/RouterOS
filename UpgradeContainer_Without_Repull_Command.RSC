:local stopAndRemoveTimeout 15
:local addTimeout 180
:local errorRetryCount 3
:local doNotUpgradeContainer [:toarray ("mihomo:latest") ]
:local dnsContainer "adguardhome"
:local testUrl "https://hub.docker.com"
:local validAddArgs ("comment","remote-image","check-certificate","name","interface","env","envlists","cmd","entrypoint","stop-signal","stop-time","root-dir","layer-dir","mount","mountlists","dns","hostname","domain-name","workdir","logging","start-on-boot","auto-restart-interval","cpu-list","memory-high","devices","hosts")

:local escapeStr do={
    :local strLen [:len $1]
    :local escStr ""

    :for i from=0 to=($strLen-1) do={
        :local chr [:pick $1 $i ($i+1)]

        :if ($chr="\$") do={
            :set escStr "$escStr\\\$" 
        } else={
            :if ($chr="\\") do={
                :set escStr "$escStr\\\\" 
            } else={
                :if ($chr="\"") do={
                    :set escStr "$escStr\\\"" 
                } else={
                    :set escStr "$escStr$chr"
                }
            }
        }
    }
    :return "\"$escStr\""
}

:local arrayToStr do={
    :local arrLen [:len $1]
    :local strArr "("

    :for i from=0 to=($arrLen-1) do={
        :local item [:pick $1 $i]

        :if ([:len $strArr]>1) do={
            :set $strArr "$strArr," 
        }
        :if ([:typeof $item]="str") do={
            :set $strArr "$strArr$([$escapeStr $item])"
        } else={
            :set $strArr "$strArr$item"
        }
    }
    :return "$strArr)"
}

:local escapeValue do={
    :if ([:typeof $1]="str") do={
        :return [$escapeStr $1] 
    }
    :if ([:typeof $1]="array") do={
        :return [$arrayToStr $1 escapeStr=$escapeStr] 
    }
    :if ([:typeof $1]="bool") do={
        :if ($1) do={
            :return "yes" 
        } else={
            :return "no" 
        }
    }
    :return $1
}

:local checkDoNotUpgrade do={
    :for i from=0 to=([:len $2]-1) do={
        :if ([:find $1 [:pick $2 $i]]>=0) do={
            :return false
        }
    }
    :return true
}

:local upgradeContainer do={
    :local currentContainer [/container find remote-image=$1]
    /container stop $currentContainer
    :local sec 0
    :while ([/container get $currentContainer stopped]=[]&&!([/container get $currentContainer about]~"error")&&$sec<$2) do={
        :delay 1
        :set sec ($sec+1)
    }

    :if ($sec<$2) do={
        /container remove $currentContainer
        :set sec 0
        :while ([/container find remote-image=$1]!=""&&$sec<$2) do={
            :delay 1
            :set sec ($sec+1)
        }
        :if ($sec<$2) do={
            :execute $3 as-string
            :set currentContainer [/container find remote-image=$1]
            :set sec 0
            :while ([/container get $currentContainer about]=[]&&$sec<$4) do={
                :delay 1
                :set sec ($sec+1)
            }
            :while ([/container get $currentContainer about]~"extracting"||[/container get $currentContainer about]~"downloading"&&$sec<$4) do={
                :delay 1
                :set sec ($sec+1)
            }

            :if ($sec<$4) do={
                :if (!([/container get $currentContainer about]~"error")) do={
                    :if ($5=true) do={
                        /container start $currentContainer
                    }
                    :return "Successful"
                } else={
                    /log error "Container $1 upgrade failed"
                }
            } else={
                /log error "Container $1 upgrade timed out"
            }
        } else={
            /log error "Container $1 remove timed out"
        }    
    } else={
        /log error "Container $1 stop timed out"
    }
    :delay 5
    :return "Failed"
}

:local currentDNS
:local upgradeResult
:local checkContainerStatus [:parse [/system/script get CheckContainerStatus source]]
:do {
    :if ([:toarray [/tool/fetch output=none url=$testUrl as-value]]->"status"="finished") do={
        :foreach container in=[/container print detail as-value] do={
            :local containerImage ($container->"remote-image")
            :if ([:len $globalDoNotUpgradeContainer]>0) do={
                :set doNotUpgradeContainer $globalDoNotUpgradeContainer
            }
            :if ([$checkDoNotUpgrade $containerImage $doNotUpgradeContainer]&&[:find $containerImage "/"]>=0) do={
                :local isContainerRunning ($container->"running")
                :if ([:find $containerImage $dnsContainer]>=0) do={
                    :set currentDNS [/ip/dns get servers]
                    /ip/dns set servers=223.5.5.5
                    /ip/dns cache flush
                    :delay 3
                }
                :local addCmd "/container add"
                :foreach k,v in=$container do={
                    :if ([:len $v]!=0) do={
                        :if ([:find $validAddArgs $k]>=0) do={
                            :set addCmd "$addCmd $k=$([$escapeValue $v escapeStr=$escapeStr arrayToStr=$arrayToStr])"
                        }
                   }
                }

                :local count
                :local result
                :while ($result!="Successful"&&$count<$errorRetryCount) do={
                    :set count ($count+1)
                    :set result [$upgradeContainer $containerImage $stopAndRemoveTimeout $addCmd $addTimeout $isContainerRunning]
                }

                :if ([:len $currentDNS]>0) do={
                    :if ([$checkContainerStatus $dnsContainer]=true) do={
                        /ip/dns set servers=$currentDNS
                        :delay 5
                    } else={
                        /log error "DNS container not running,please check it manually and change your DNS settings"
                    }
                    :set currentDNS ""
                }
                :set upgradeResult "$upgradeResult $containerImage $result\n"
            }
        }
        :if ([:find $upgradeResult "Failed"]>=0 ) do={
            :local sendMsg [:parse [/system/script get Msg2WeChat source]]
            $sendMsg msgTitle="Container upgrade report" msgContent=$upgradeResult
        }
    }
} on-error={
    /log error "Someting went wrong,ensure you can access the docker server.Upgrade failed"
}
