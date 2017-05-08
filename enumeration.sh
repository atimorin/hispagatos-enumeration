#!/usr/bin/env bash
# ReK2 Fernandez Chris
# hispagatos hacking collective
# https://hispagatos.org 
# https://keybase.io/cfernandez

set -eo pipefail
ulimit -n 4090

############## Variables #############
WORKINGDIR=~/hacking
TARGET="$@"
NMAPP="/usr/bin/nmap"
ENUM4LINUX="/usr/bin/enum4linux"
NIKTO="/usr/bin/nikto"
TARGETDIR="${WORKINGDIR}/${TARGET}"
TARGETNOTES="${TARGETDIR}/${TARGET}-NOTES"
#####################################

if [ $# -eq 0 ] ||  [ -z "$1" ];
  then
    echo "No arguments supplied"
    exit 1
fi

if [ ! -d  ${WORKINGDIR} ];
  then
    mkdir ${WORKINGDIR} 
fi

if [ ! -d  ${TARGETDIR} ];
  then
    mkdir ${TARGETDIR}
fi

if [ ! -f ${TARGETNOTES} ];
  then
    touch ${TARGETNOTES} 
fi

echo "############# Starting ###############" >> ${TARGETNOTES}
echo "working directory: ${WORKINGDIR}"       >> ${TARGETNOTES}
echo "Target: ${TARGET}"                      >> ${TARGETNOTES}
echo "Target directory: ${TARGETDIR}"         >> ${TARGETNOTES}
echo "Target Notes: ${TARGETNOTES}"           >> ${TARGETNOTES}
echo "######################################" >> ${TARGETNOTES}
echo ""                                       >> ${TARGETNOTES}
echo ""                                       >> ${TARGETNOTES}


$NMAPP -Pn -p- -vv $TARGET -oA ${TARGETDIR}/${TARGET}-BASIC-Pn-allports


cat ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.nmap | sed '/open/!d' | cut -d "/" -f 1 > /tmp/${TARGET}-raw-ports

TCPOPEN=$(paste -d, -s /tmp/${TARGET}-raw-ports)

egrep -v "^#|Status: Up" ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.gnmap | cut -d' ' -f2-  | sed -n -e 's/Ignored.*//p' \
| awk '{print "Host: " $1 " TCP Ports: " NF-1; $1=""; for(i=2; i<=NF; i++) { a=a" "$i; }; split(a,s,","); for(e in s) { split(s[e],v,"/"); printf "%-8s %s/%-7s %s\n" , v[2], v[3], v[1], v[5]}; a="" }' >> ${TARGETNOTES}


echo "<center><h1>${TARGET}</h1></center>" > ${TARGETDIR}/index.html
txt2html ${TARGETNOTES}  >> ${TARGETDIR}/index.html --preformat_trigger_lines=0


#egrep -v "^#|Status: Up" ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.gnmap | cut -d ' ' -f4- | tr ',' '\n' | \
#sed -e 's/^[ \t]*//' | awk -F '/' '{print $7}' | grep -v "^$" | sort | uniq -c \
#| sort -k 1 -nr > ${TARGETNOTES}


sudo $NMAPP -Pn -sV -O -pT:${TCPOPEN} --script="default,vuln and not auth" ${TARGET} -oA ${TARGETDIR}/${TARGET}-VULN

Xalan -a ${TARGETDIR}/${TARGET}-VULN.xml > ${TARGETDIR}/${TARGET}-VULN.html


if [[ $TCPOPEN == *"445"* ]] || [[ $TCPOPEN == *"139"* ]]; then

  $ENUM4LINUX -a ${TARGET} >  ${TARGETDIR}/${TARGET}-ENUM4LINUX || true

  txt2html ${TARGETDIR}/${TARGET}-ENUM4LINUX > ${TARGETDIR}/${TARGET}-ENUM4LINUX.html

  $NMAPP -Pn -p445,135,139 --script="smb-* and not auth" ${TARGET} -oA ${TARGETDIR}/${TARGET}-all-SMB
  
  Xalan -a ${TARGETDIR}/${TARGET}-all-SMB.xml  > ${TARGETDIR}/${TARGET}-all-SMB.html

fi



if [[ $TCPOPEN == *"80"* ]] || [[ $TCPOPEN == *"443"* ]] || [[ $TCPOPEN == *"8080"* ]] ; then

  $NMAPP -Pn -p80,443,8080 --script="http-vuln*,http-enum,http-useragent-tester,http-userdir-enum,http-sql-injection,http-robots.txt,http-rfi-spider,http-php-version,http-phpmyadmin-dir-traversal,http-passwd" ${TARGET} -oA ${TARGETDIR}/${TARGET}-all-HTTP

  Xalan -a ${TARGETDIR}/${TARGET}-all-HTTP.xml > ${TARGETDIR}/${TARGET}-all-HTTP.html

  sudo $NIKTO -port ${TCPOPEN} -host ${TARGET} -output ${TARGETDIR}/${TARGET}-NIKTO.xml || true

  Xalan -a  ${TARGETDIR}/${TARGET}-NIKTO.xml > ${TARGETDIR}/${TARGET}-NIKTO.html

  dirb http://${TARGET} /usr/share/dirb/wordlists/vulns/apache.txt,/usr/share/dirb/wordlists/common.txt,/usr/share/dirb/wordlists/indexes.txt > ${TARGETDIR}/${TARGET}-Dirb || true

  txt2html ${TARGETDIR}/${TARGET}-Dirb > ${TARGETDIR}/${TARGET}-Dirb.html 

  fimap -u http://${TARGET}/ > ${TARGETDIR}/${TARGET}-fimap || true

  txt2html ${TARGETDIR}/${TARGET}-fimap > ${TARGETDIR}/${TARGET}-fimap.html
  
  echo "OPEN ZAPROXY and do enumeration of the WEBAPP's"
fi

if [[ $TCPOPEN == *"161"* ]] || [[ $TCPOPEN == *"162"* ]]; then

 $NMAPP -Pn -p161,162 --script="snmp-*" -oA ${TARGETDIR}/${TARGET}-all-SNMP

 Xalan -a ${TARGETDIR}/${TARGET}-all-SNMP.xml > ${TARGETDIR}/${TARGET}-all-SNMP.html

fi

/usr/bin/searchsploit --nmap ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.xml > ${TARGETDIR}/${TARGET}-exploit-list

txt2html ${TARGETDIR}/${TARGET}-exploit-list > ${TARGETDIR}/${TARGET}-exploit-list.html



echo "<table border="1">"                         >> ${TARGETDIR}/index.html
echo "<caption><em>RAW RESULTS FROM SCANS \
      AND ENUMERATION</em></caption>"             >> ${TARGETDIR}/index.html

for create in $(ls ${TARGETDIR}/*.html | cut -d "/" -f 6);
  do
  if [ ! $create == "index.html" ];
    then
      echo "<tr>"                                 >> ${TARGETDIR}/index.html
      echo "<td>"                                 >> ${TARGETDIR}/index.html
      echo "<a href=\"${create}\">${create}</a>"  >> ${TARGETDIR}/index.html
      echo "</td>"                                >> ${TARGETDIR}/index.html
      echo "</tr>"                                >> ${TARGETDIR}/index.html
  fi
done
echo "</table>"                                   >> ${TARGETDIR}/index.html
