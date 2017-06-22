#!/bin/sh

# installtion script for simplesamlphp IdP
# jiny92@kisti.re.kr (KAFE federation) 2016/1/26
# updated 2016/1/25 (v 0.10)
# History

source ./config.sh


DOMAIN_NAME_PORT=$(echo $MEMBER_IDPURL | awk -F/ '{print $3}')
DOMAIN_NAME=$(echo $DOMAIN_NAME_PORT | awk -F: '{print $1}')

DOMAIN_TO_ADDR=$(nslookup $DOMAIN_NAME | tail -2 | head -1 | awk -F ":" '{print $2}')
SERVER_TO_ADDR=$(nslookup $SERVER_NAME | tail -2 | head -1 | awk -F ":" '{print $2}')

# assuming that both have domain names
DOMAIN_FLAG=1
SERVER_FLAG=1

if grep -q "NXDOMAIN" <<< $DOMAIN_TO_ADDR; then
        echo "MEMBER_IDPURL is either invalid domain name or an IP address."

        # if DOMAIN_NAME is an ip addr
        if [ $(ipcalc -cs $DOMAIN_NAME && echo 1 || echo 0) == 1 ]; then
                echo "MEMBER_IDPURL has a valid IP address."
                DOMAIN_FLAG=0
        else
                echo "Invalid MEMBER_IDPURL. check your configuration"
                exit
        fi
fi


if grep -q "NXDOMAIN" <<< $SERVER_TO_ADDR; then
        # if SERVER_NAME is an ip addr
        if [ $(ipcalc -cs $SERVER_NAME && echo 1 || echo 0) == 1 ]; then
                echo "SERVER_NAME is a valid IP address."
                SERVER_FLAG=0
        fi
fi

if [ $SERVER_FLAG -eq $DOMAIN_FLAG ]; then
        if [ $DOMAIN_NAME != $SERVER_NAME ]; then
                echo "Different URI format. Check your SERVER_NAME and MEMBER_IDPURL"
                exit
        fi
fi

declare -a HOST_ADDR
HOST_ADDR=$(hostname -I)
TMP_ADDR=$(nslookup $SERVER_NAME | tail -2 | head -1 | awk -F ":" '{print $2}')

if grep -q "NXDOMAIN" <<< $TMP_ADDR; then
        if [ $(ipcalc -cs $SERVER_NAME && echo 1 || echo 0) == 1 ]; then
                echo "Valid server IP. keep going."
                TMP_ADDR=$SERVER_NAME
        else
                echo "invalid ip address. check your configuration."
                exit 1
        fi
fi

if [[ "${HOST_ADDR[@]}" =~ "$TMP_ADDR" ]]; then
        echo "ok. properly set the ip address of this machine"
else
        echo "invalid SERVER_NAME. check your configuration"
        exit
fi


if grep -q $META_SCOPE <<< $MEMBER_ORGURL; then
        echo "META_SCOPE is within the scope"
else
        echo "META_SCOPE is out of the scope. check your META_SCOPE configuration"
        exit
fi

echo "cron key is "$CRON_KEY

if ! [ -f /usr/bin/lsb_release ]; then
        echo "no redhat-lsb found. now installing"
        yum -y install redhat-lsb
fi

if ! [ -f /usr/bin/wget ]; then
        echo "no wget found. now installing"
        yum -y install wget
fi

OS=$(lsb_release -si)
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VER=$(lsb_release -sr)

if [ $OS == "CentOS" -a $ARCH == "64" ]
then 
	if [ $VER == "6.7" -o $VER == "6.8" ]; then
		echo "Ok. keep going"
	else
		echo "Opps. This script works for CentOS 6.7/6.8 (64-bit only)"
		exit 1

	fi
else
	echo "Oops. not working on this Linux distribution. This script works for CentOS 6.7/6.8 (64-bit only)"
	exit 1
fi

if ! [ -d $SSP_PATH ]; then
	echo "no simpleSAMLphp found. aborting"
	exit 1
fi

echo $SSP_PATH |grep '/$' > /dev/null
if [ $? -eq 0 ]; then
        SSP_PATH=$SSP_PATH
else
        SSP_PATH=$SSP_PATH"/"
fi

touch $SSP_PATH"modules/cron/enable"
cp "$SSP_PATH"modules/cron/config-templates/*.php "$SSP_PATH"config

touch $SSP_PATH"modules/metarefresh/enable"
cp "$SSP_PATH"modules/metarefresh/config-templates/*.php "$SSP_PATH"config


TEST_REFRESH=$SSP_PATH"modules/metarefresh/bin/metarefresh.php -s https://fedinfo.kreonet.net/signedmetadata/federation/"$KAFE_FEDMETANAME"/metadata.xml"
if $TEST_REFRESH | grep "'metarefresh:src'" > /dev/null; then
	echo "Ok, successfully completed patching federation metadata."
else
	echo "Oops. failed to patch federaton metadata. aborting"
	exit 1
fi

if ! [ -f ./cron.template ]; then
	echo "no cron.template found. aborting"
	exit 1
fi

cp cron.template module_cron.php
sed -i "s|SECRET|$CRON_KEY|g" ./module_cron.php

mv module_cron.php "$SSP_PATH"config/module_cron.php

crontab -l > crontab.tmp

# fix me
if grep "KAFE_DAILY_PATCH" crontab.tmp > /dev/null; then
	echo "found existing crontab [daily] configuration. deleting old setup."
	sed -i '/KAFE_DAILY_PATCH/,+1d' crontab.tmp
fi		

if grep "KAFE_HOURLY_PATCH" crontab.tmp > /dev/null; then
	echo "found eisting crontab [hourly] configuration. deleting old setup."
	sed -i '/KAFE_HOURLY_PATCH/,+1d' crontab.tmp
fi

cat crontab.template >> crontab.tmp

sed -i "s|CRONURL|$CRON_URL|g" crontab.tmp
sed -i "s|CRONKEY|$CRON_KEY|g" crontab.tmp

crontab crontab.tmp
rm -rf crontab.tmp


cp ./metarefresh.template ./config-metarefresh.php
sed -i "s|METADATA_FETCH_URL|https://fedinfo.kreonet.net/signedmetadata/federation/$KAFE_FEDMETANAME/metadata.xml|g" config-metarefresh.php
sed -i "s|METADATA_PATCH_FOLDER|$META_DIR|g" config-metarefresh.php

cp config-metarefresh.php "$SSP_PATH"config/
rm -rf config-metarefresh.php

mkdir -p "$SSP_PATH"metadata/metadata-kafe-test
chown apache.apache "$SSP_PATH"metadata/metadata-kafe-test

if grep "array('type' => 'flatfile', 'directory' => 'metadata/$META_DIR')" "$SSP_PATH"config/config.php > /dev/null; then
	echo "found existing metadata.sources configuration. deleting."
	sed -i "/array('type' => 'flatfile', 'directory' => 'metadata\/metadata-kafe-test')/ d" "$SSP_PATH"config/config.php
fi

sed -i "/'metadata.sources' => array(/a\ 	 array('type' => 'flatfile', 'directory' => 'metadata/$META_DIR')," "$SSP_PATH"config/config.php
#delete next line
sed -i "/* 'metadata.sources' => array(/{n;d}" "$SSP_PATH"config/config.php

chcon -R -h -t httpd_sys_content_t "$SSP_PATH"config/
