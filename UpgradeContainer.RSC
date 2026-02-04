#停止以及删除容器的超时时间
:local stopAndRemoveTimeout 15
#添加容器的超时时间
:local addTimeout 120
#出错后重试次数
:local errorRetryCount 3
#不需要更新的容器的关键词
:local doNotUpgradeContainer [ :toarray ("mihomo","example") ]
#DNS容器的关键词
:local dnsContainer "adguardhome"
#测试能否访问镜像服务器的网址
:local testUrl "https://hub.docker.com"
#容器参数
:local validAddArgs ("cmd", "comment", "dns", "domain-name", "entrypoint", "envlist", "hostname", "interface", "logging", "mounts", "root-dir", "start-on-boot", "workdir")
:local replaceArgs { "tag"="remote-image" }

:local escapeStr do={
    :local strLen [:len $1]
    :local escStr ""

    :for i from=0 to=($strLen - 1) do={
        :local chr [:pick $1 $i ($i + 1)]

        :if ($chr = "\$") do={
            :set escStr "$escStr\\\$" 
        } else={
            :if ($chr = "\\") do={
                :set escStr "$escStr\\\\" 
            } else={
                :if ($chr = "\"") do={
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

    :for i from=0 to=($arrLen - 1) do={
        :local item [:pick $1 $i]

        :if ([:len $strArr] > 1) do={
            :set $strArr "$strArr," 
        }
        :if ([:typeof $item] = "str") do={
            :set $strArr "$strArr$([$escapeStr $item])"
        } else={
            :set $strArr "$strArr$item"
        }
    }
    :return "$strArr)"
}

:local escapeValue do={
    :if ([:typeof $1] = "str") do={
        :return [$escapeStr $1] 
    }
    :if ([:typeof $1] = "array") do={
        :return [$arrayToStr $1 escapeStr=$escapeStr] 
    }
    :if ([:typeof $1] = "bool") do={
        :if ($1) do={
            :return "yes" 
        } else={
            :return "no" 
        }
    }
    :return $1
}

:local checkDoNotUpgrade do={
    :for i from=0 to=([:len $2] - 1) do={
        :if ([:find $1 [:pick $2 $i]] >= 0) do={
            :return false
        }
    }
    :return true
}

:local upgradeContainer do={
    :local currentContainer [/container find tag=$1]
    /container stop $currentContainer
    :local sec 0
    :while ([/container get $currentContainer status] != "stopped" && [/container get $currentContainer status] != "error" && $sec < $2) do={
        :delay 1
        :set sec ($sec + 1)
    }

    :if ($sec < $2) do={
        /container remove $currentContainer
        :set sec 0
        :while ([/container find tag=$1] != "" && $sec < $2) do={
            :delay 1
            :set sec ($sec + 1)
        }

        :if ($sec < $2) do={
            :execute $3 as-string
            :set currentContainer [/container find tag=$1]
            :set sec 0  
            :while ([/container get $currentContainer status] = "extracting" && $sec < $4) do={
                :delay 1
                :set sec ($sec + 1)
            }

            :if ($sec < $4) do={
                :if ([/container get $currentContainer status] = "stopped") do={
                    :if ($5 = "running") do={
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

# Main function
:local currentDNS
:local upgradeResult
:do {
    :if ([:toarray [/tool fetch output=none url=$testUrl as-value]]->"status" = "finished") do={
        :foreach container in=[/container/print as-value] do={
            :local containerTag ($container->"tag")
            #可以在其他脚本中用以下两行代码调用本脚本，通过指定 globalDoNotUpgradeContainer 参数的值，实现更新特定容器
            #:local upgradeContainer [:parse [/system script get UpgradeContainer source]]
            #$upgradeContainer globalDoNotUpgradeContainer=[ :toarray ("mihomo","ddns") ]
            :if ([:len $globalDoNotUpgradeContainer] > 0) do={
                :set doNotUpgradeContainer $globalDoNotUpgradeContainer
            }
            
            :if ([$checkDoNotUpgrade $containerTag $doNotUpgradeContainer] && [:find $containerTag "/"] >= 0) do={
                :local containerStatus ($container->"status")
                :if ([:find $containerTag $dnsContainer] >= 0) do={
                    :set currentDNS [/ip dns get servers]
                    /ip dns set servers=223.5.5.5
                    /ip dns cache flush
                }

                :local addCmd "/container add"
                :foreach k,v in=$container do={
                    :if ([:len $v] != 0) do={
                        :if ([:find $validAddArgs $k] >= 0) do={
                            :set addCmd "$addCmd $k=$([$escapeValue $v escapeStr=$escapeStr arrayToStr=$arrayToStr])"
                        } else={
                            :local rk ($replaceArgs->"$k")
                            :if ([:typeof $rk] != "nothing") do={
                                :set addCmd "$addCmd $rk=$([$escapeValue $v escapeStr=$escapeStr arrayToStr=$arrayToStr])"
                            }
                       }
                   }
                }

                :local count
                :local result
                :while ($result != "Successful" && $count < $errorRetryCount) do={
                    :set count ($count + 1)
                    :set result [$upgradeContainer $containerTag $stopAndRemoveTimeout $addCmd $addTimeout $containerStatus]
                }

                :if ([:len $currentDNS] > 0) do={
                    :if ([/container get [find tag~$dnsContainer] status] = "running") do={
                        /ip dns set servers=$currentDNS
                        :delay 3
                    } else={
                        /log error "DNS container not running,please check it manually and change your DNS settings"
                    }
                    :set currentDNS ""
                }
                :set upgradeResult "$upgradeResult $containerTag $result\n"
            }
        }
        :if ([:find $upgradeResult "Failed"] >= 0 ) do={
            #创建一个脚本,脚本名Msg2WeChat，内容如下，可以实现调用该脚本发送信息到邮箱以及微信
            #/tool fetch output=none http-method=post url="https://sctapi.ftqq.com/Server酱上你的Key.send" http-data="noip=1&text=$msgTitle&desp=$msgContent"
            #/tool e-mail send to=example@example.com subject=$msgTitle body=$msgContent
            :local sendMsg [:parse [/system script get Msg2WeChat source]]
            $sendMsg msgTitle="Container upgrade report" msgContent=$upgradeResult
        }
    }
} on-error={
    /log error "Someting went wrong,ensure you can access the docker server.Upgrade failed"
}