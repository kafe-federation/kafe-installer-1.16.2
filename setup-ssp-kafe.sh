#!/bin/sh

# installtion script for simplesamlphp IdP
# jiny92@kisti.re.kr (KAFE federation) 2018/10/1
# updated 2018/10/12 (v 0.12)
# History

source ./config.sh

DOMAIN_NAME_PORT=$(echo $MEMBER_IDPURL | awk -F/ '{print $3}')
DOMAIN_NAME=$(echo $DOMAIN_NAME_PORT | awk -F: '{print $1}')

DOMAIN_TO_ADDR=$(nslookup $DOMAIN_NAME | tail -2 | head -1 | awk -F ":" '{print $2}')
SERVER_TO_ADDR=$(nslookup $SERVER_NAME | tail -2 | head -1 | awk -F ":" '{print $2}')

# assuming that both have domain names
DOMAIN_FLAG=1
SERVER_FLAG=1

if [ $IP_TYPE = "public" ]; then
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
fi

if [ $IP_TYPE = "public" ]; then
 if grep -q "NXDOMAIN" <<< $SERVER_TO_ADDR; then
	# if SERVER_NAME is an ip addr
	if [ $(ipcalc -cs $SERVER_NAME && echo 1 || echo 0) == 1 ]; then
		echo "SERVER_NAME is a valid IP address."
		SERVER_FLAG=0
	fi
 fi
fi

if [ $IP_TYPE = "public" ]; then
  if [ $SERVER_FLAG -eq $DOMAIN_FLAG ]; then
	if [ $DOMAIN_NAME != $SERVER_NAME ]; then
		echo "Different URI format. Check your SERVER_NAME and MEMBER_IDPURL"
		exit
	fi
  fi
fi

#HOST_ADDR 변수를 배열로 선언
declare -a HOST_ADDR
HOST_ADDR=$(hostname -I)
TMP_ADDR=$(nslookup $SERVER_NAME | tail -2 | head -1 | awk -F ":" '{print $2}')

if [ $IP_TYPE = "public" ]; then
  if grep -q "NXDOMAIN" <<< $TMP_ADDR; then
	if [ $(ipcalc -cs $SERVER_NAME && echo 1 || echo 0) == 1 ]; then
		echo "Valid server IP. keep going."
		TMP_ADDR=$SERVER_NAME
	else
		echo "invalid ip address. check your configuration."
		exit 1
	fi
  fi
fi

#if [ $IP_TYPE = "public" ]; then
#  if [ $TMP_ADDR = $HOST_ADDR ]; then
# if [[ "${HOST_ADDR[@]}" =~ "$TMP_ADDR" ]]; then # 호스트가 다중 IP를 가질 경우를 대비
#	echo "ok. properly set the ip address of this machine"
#  else
#	echo "invalid SERVER_NAME. check your configuration"
#	exit
#  fi
#fi

if grep -q $META_SCOPE <<< $MEMBER_ORGURL; then
	echo "META_SCOPE is within the scope"
else
	echo "META_SCOPE is out of the scope. check your META_SCOPE configuration"
	exit
fi


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
VER_STR=$(lsb_release -sr)
VER=$(echo $VER_STR | head -c 1)

if [ $OS == "CentOS" -a $ARCH == "64" ]; then 
   if [ $VER -ge 7 ]; then 
	echo "Ok. keep going"
   else
	echo "This script works for CentOS 7 and above (64-bit only)"
	exit 1
   fi
else
  	echo "Oops. not working on this Linux distribution. This script works for CentOS 7 and above (64-bit) only"
	exit 1
fi


echo "[Update CentOS]"
yum update

echo ""

######################### disabling selinux#############################

#echo "[Disable SELinux] it disables selinux for easy configuration. We recommend you re-config the selinux after completing IdP setup."
#read enter

#echo 0 > /selinux/enforce
#sed -i 's/enforcing/disabled/g' /etc/selinux/config

#echo ""
########################## enabling ntp ################################
echo "[NTP setup] it enables NTP (Network Time Protocol). it is menatory to synchronize time among entities. \
NTP time server is set to time.kriss.re.kr"
#read enter

ntpstat > /dev/null
if [ $? -gt 0 ]; then
	echo "	NTP is not running"
	if ! [ -x /usr/sbin/ntpd ]; then
		echo "	NTP is not installed. Now installing"
yum -y install ntp ntpdate
	fi 
else
	echo "	NTP is running"
	service ntpd stop
fi

sed -i 's/0.centos.pool.ntp.org/time.kriss.re.kr/g' /etc/ntp.conf
service ntpd start
chkconfig ntpd on

echo ""

##########################open firewall port#############################

echo "[Firewall setup] it denies all incoming requests except for FIM-related ones."

#iptables-restore < ./iptables.template
#iptables-save > /etc/sysconfig/iptables

systemctl stop firewalld

echo ""


#################### installing software packages ######################

echo "[Package setup] it installs required software packages for simpleSAMLphp. \
The packages include php-date, openssl, mysql, mysql-server, php-mysql, php-mcrypt."
#read enter


yum -y install php httpd php-common php-pdo php-mbstring php-pear php-mysql php-gd php-date openssl mysql mysql-server mod_ssl php-xml
yum -y install epel-release
yum -y install php-mcrypt

if [ $BACKEND_DB = "ldap" ] 
then
    yum -y install php-ldap
fi

PHP_VER=$(php -v|grep --only-matching --perl-regexp "5\.\\d+\.\\d+")

rpm -ivh https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
yum -y update
yum -y install php-mcrypt 
yum -y install php-mysql

systemctl enable mysqld
systemctl start mysqld

rpm -ivh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm

echo "removing previous mysql server installation"
systemctl stop mysqld && yum remove -y mysql mysql-server && rm -rf /var/lib/mysql && rm -rf /var/log/mysqld.log && rm -rf /etc/my.cnf
yum install -y mysql-server

if [ ! -f /etc/my.cnf ]
then
	cp ./mycnf.template /etc/my.cnf
fi

systemctl start mysqld
TEMPROOTDBPASS="`grep 'temporary.*root@localhost' /var/log/mysqld.log | tail -n 1 | sed 's/.*root@localhost: //'`"

mysqladmin -u root --password="$TEMPROOTDBPASS" password "$SQL_DB_PASS"
mysql -u root --password="$SQL_DB_PASS" <<-EOSQL
    DELETE FROM mysql.user WHERE User='root';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    DELETE FROM mysql.user where user != 'mysql.sys';
    CREATE USER 'root'@'%' IDENTIFIED BY '${SQL_DB_PASS}';
    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
EOSQL

if test -d "/var/lib/mysql/user_db_test"; then
        echo "database exists. skip configuring DB"
else
        mysql -u$SQL_DB_USER -p$SQL_DB_PASS < testdb.sql
fi

if test -d "/var/lib/mysql/consent"; then
	echo "consent database exists. skip configuring DB"
else
	mysql -u$SQL_DB_USER -p$SQL_DB_PASS < consent.sql
fi

echo ""


################### downloading simplesamlphp #########################
echo "[simpleSAMLphp installation] it downloads the latest simplesamlphp from simplesamlphp.org. \
The package will be placed on ". $SSP_PATH ." run of this script will replace old SSP configuration."
#read enter

#wget https://github.com/coreen-kafe/simplesamlphp-1.16.2/archive/master.zip
wget https://github.com/kafe-federation/simplesamlphp-kafe/archive/kafe-1.16.2.zip -O master.zip

if [ -d $SSP_PATH ]; then
	echo "existing simplesamlphp directory found. deleting"
	rm -rf $SSP_PATH
fi

if [ ! -s master.zip ]; then
	echo "installation error. unable to download simplesamlphp."
	exit 1
fi

unzip master.zip > /dev/null && rm -rf master.zip
mkdir -p $SSP_PATH && mv simplesamlphp-*/ simplesamlphp && cp -r simplesamlphp/* $SSP_PATH
rm -rf simplesamlphp

# 보안 컨텍스트 변경
#chcon -R -h -t httpd_sys_content_t $SSP_PATH

echo ""

################### configure web server ##############################

echo "[Apache setup] it configs Apache web server. Make sure that it skips HTTPS setup. \
You have to enable HTTPS by userself."
#read enter

cp ssl.template ssl.cnf

sed -i "s/CITYNAME/$SSL_CITYNAME/g" ssl.cnf
sed -i "s/COMPANYNAME/$SSL_COMPANYNAME/g" ssl.cnf
sed -i "s/DEPTNAME/$SSL_DEPTNAME/g" ssl.cnf
sed -i "s/SERVERNAME/$SERVER_NAME/g" ssl.cnf
sed -i "s/ADMINMAIL/$SSP_ADMIN_MAIL/g" ssl.cnf

openssl genrsa -out ca.key 2048
openssl req -new -x509 -nodes -days 365 -key ca.key -out ca.crt -config ssl.cnf -batch

cp ca.crt /etc/pki/tls/certs
cp ca.key /etc/pki/tls/private/ca.key


if grep "## DO NOT MODIFY THIS LINE ##" /etc/httpd/conf/httpd.conf > /dev/null; then
        echo "found existing apache configuration. deleting the old one."
	sed -i '/DO NOT MODIFY THIS LINE/ ,$d' /etc/httpd/conf/httpd.conf
fi

echo 	"updating apache configuration."

if grep "Alias /simplesaml" /etc/httpd/conf.d/ssl.conf > /dev/null; then
	echo "existing ssl.conf found. skip configuring"
else
	echo "adding new one"
	sed -i -e "/#<\/VirtualHost>/r apache-ssl.template" /etc/httpd/conf.d/ssl.conf
	sed -i "s|SSPPATHHERE|$SSP_PATH|g" /etc/httpd/conf.d/ssl.conf
fi

cat apache.template >> /etc/httpd/conf/httpd.conf
sed -i "s/SERVERNAMEHERE/$SERVER_NAME/g" /etc/httpd/conf/httpd.conf
sed -i "s|SSPPATHHERE|$SSP_PATH|g" /etc/httpd/conf/httpd.conf

sed -i "s|SSLCertificateFile /etc/pki/tls/certs/localhost.crt|SSLCertificateFile /etc/pki/tls/certs/ca.crt|g" /etc/httpd/conf.d/ssl.conf
sed -i "s|SSLCertificateKeyFile /etc/pki/tls/private/localhost.key|SSLCertificateKeyFile /etc/pki/tls/private/ca.key|g" /etc/httpd/conf.d/ssl.conf

rm -rf ./ca.*

# 보안 컨텍스트 복원
#restorecon -RvF /etc/pki/

systemctl restart httpd

echo ""

################### configure SSP ##############################
echo "[simpleSAMLphp setup] it updates config/config.php (saltkey, timezone, admin password, contact, etc). "

SALT=$(tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo)
sed -i 's/defaultsecretsalt/'"$SALT"'/g' $SSP_PATH/config/config.php
sed -i "s/'timezone' => null/'timezone' => 'Asia\/Seoul'/g" $SSP_PATH/config/config.php
sed -i "s/'enable.saml20-idp' => false/'enable.saml20-idp' => true/g" $SSP_PATH/config/config.php
sed -i "s/'auth.adminpassword' => '123'/'auth.adminpassword' => '$SSP_ADMIN_PASS'/g" $SSP_PATH/config/config.php
sed -i "s/'technicalcontact_name' => 'Administrator'/'technicalcontact_name' => '$SSP_ADMIN_NAME'/g" $SSP_PATH/config/config.php
sed -i "s/'technicalcontact_email' => 'na@example.org'/'technicalcontact_email' => '$SSP_ADMIN_MAIL'/g" $SSP_PATH/config/config.php

if ! [ -s $SSP_PATH/modules/exampleauth/enable ]; then
	echo "enabling exampleauth module"
	touch $SSP_PATH/modules/exampleauth/enable
fi

echo ""


############## installing self-signed certificate ##############

echo "[SSL certificate] it installs a self-signed certificate for simpleSAMLphp. you MUST NOT use any commercial certificate except for HTTPS."

if ! [ -d $SSP_PATH/cert ]; then
	echo "making a cert directory"
	mkdir -p $SSP_PATH/cert
fi

if [ -f ./kafe-member-idp.crt ]; then
	rm -rf kafe-member-idp.*
fi

if ! [ -f $SSP_PATH/cert/kafe-member-idp.crt ]; then
	openssl req -newkey rsa:4096 -new -x509 -sha256 -days 3652 -nodes -out kafe-member-idp.crt -keyout kafe-member-idp.pem -config ssl.cnf -batch
	mv ./kafe-member-idp.* $SSP_PATH/cert
fi

# 보안 컨텍스트 변경
#chcon -R -h -t cert_t $SSP_PATH/cert/

echo ""

rm -rf ssl.cnf

################### configuring idp metadata ###################
echo "[Metadata setup] it registers cert-info into IdP's metadata."

sed -i 's/server.pem/kafe-member-idp.pem/g' $SSP_PATH/metadata/saml20-idp-hosted.php
sed -i 's/server.crt/kafe-member-idp.crt/g' $SSP_PATH/metadata/saml20-idp-hosted.php

sed -i "/'auth' => 'example-userpass',/a\	'userid.attribute' => 'uid'," $SSP_PATH/metadata/saml20-idp-hosted.php 
sed -i "s/'auth' => 'example-userpass'/'auth' => 'kafe-userpass'/g" $SSP_PATH/metadata/saml20-idp-hosted.php


############## configuring authentication source ###############
echo "[Authentication-source setup] it enables you to login an Web-based service using a test user DB. \
Make sure that you have to make more configuration to enable users to login with your organizational user DB."

if grep kafe-userpass $SSP_PATH/config/authsources.php > /dev/null; then
        echo "[Warning] you must delete 'kafe-userpass' array in authsources.php if you want to make this configuration work [Enter]"
	read enter
else
	sed -i "/$config = array(/a\	'kafe-userpass' => array(\n		'kafe:CoreAuth',\n		'dsn'=>'mysql:host=localhost;dbname=$SQL_DB_NAME',\n		'username'=>'$SQL_DB_USER',\n		'password'=>'$SQL_DB_PASS',\n	)," $SSP_PATH/config/authsources.php
fi

mkdir -p $SSP_PATH/modules/kafe/lib/Auth/Source
mkdir -p $SSP_PATH/modules/kafe/lib/Auth/Process
touch $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
touch $SSP_PATH/modules/kafe/lib/Auth/Process/EntitlementFilter.php

cp ./coreauth.template $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
cp ./entitlementfilter.template $SSP_PATH/modules/kafe/lib/Auth/Process/EntitlementFilter.php

sed -i "s/YOURAUTHSOURCE/kafe/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
sed -i "s/YOURAUTHSOURCE/kafe/g" $SSP_PATH/modules/kafe/lib/Auth/Process/EntitlementFilter.php

sed -i "s/ATTR_SCOPED/$ATTRIBUTE_EPSCOPEDAFFILIATION/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
sed -i "s/ATTR_ORGNAME/$ATTRIBUTE_ORGNAME/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
sed -i "s/ATTR_SCHACHOME/$ATTRIBUTE_SCHACHOMEORG/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
sed -i "s/ATTR_EPENTITLE/$ATTRIBUTE_EPENTITLEMENT/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php

if [ $SQL_TYPE = "oracle" ]; then
	sed -i "s/ORACLE_DB_USER/$ORACLE_DB_USERNAME/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ORACLE_DB_PASS/$ORACLE_DB_PASSWORD/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
        sed -i "s/ORACLE_IP_ADDR/$ORACLE_SRV_ADDR/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
        sed -i "s/ORACLE_PORT/$ORACLE_SRV_PORT/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
        sed -i "s/ORACLE_SID/$ORACLE_SID_NAME/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ORACLE_TABLENAME/$ORACLE_TABLENAME/g"  $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ORACLE_FIELD_USERNAME/$ORACLE_FIELD_USERNAME/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
        sed -i "s/ORACLE_FIELD_PASSWORD/$ORACLE_FIELD_PASSWORD/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ORACLE_FIELD_DISPLAYNAME/$ORACLE_FIELD_DISPLAYNAME/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ORACLE_FIELD_MAIL/$ORACLE_FIELD_MAIL/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ORACLE_FIELD_EPA/$ORACLE_FIELD_EPA/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ATTRIBUTE_ORGNAME/$ATTRIBUTE_ORGNAME/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
	sed -i "s/ATTRIBUTE_SCHACHOMEORG/$ATTRIBUTE_SCHACHOMEORG/g" $SSP_PATH/modules/kafe/lib/Auth/Source/CoreAuth.php
fi

touch $SSP_PATH/modules/kafe/default-enable
touch $SSP_PATH/modules/kafe/enable

echo ""

######################### configuring saml20-idp-hosted.php

echo "[Metadata setup] it converts 'friendly name' of KAFE attributes to 'oid' format. Organizational information \
is then inserted into the IdP's metadata."

if grep "89 => array('class' => 'core:AttributeMap'," $SSP_PATH/metadata/saml20-idp-hosted.php > /dev/null; then
	echo "found existing authproc setup. skip configuration"
else
	sed -i -e "/'userid.attribute' => 'uid',/r authproc.template" $SSP_PATH/metadata/saml20-idp-hosted.php			
fi

if grep "'NameIDFormat' => 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'," $SSP_PATH/metadata/saml20-idp-hosted.php > /dev/null; then
	echo "found existing authproc setup. skip configuration"
else
	sed -i -e "/'userid.attribute' => 'uid',/r binding.template" $SSP_PATH/metadata/saml20-idp-hosted.php
fi

if grep "88 => array('class' => 'core:AttributeMap'," $SSP_PATH/config/config.php > /dev/null; then
	echo "found existing name2oid setup. skip configuration"
else
	sed -i -e "/50 => 'core:AttributeLimit',/r config.template" $SSP_PATH/config/config.php
	sed -i -e "s/DBUSER/$SQL_DB_USER/g" $SSP_PATH/config/config.php
	sed -i -e "s/DBPASS/$SQL_DB_PASS/g" $SSP_PATH/config/config.php
fi

if grep "OrganizationName" $SSP_PATH/metadata/saml20-idp-hosted.php > /dev/null; then
	echo "found existing organizational-information setup. skip configuration"
else
	sed -i -e "/'userid.attribute' => 'uid',/r org.template" $SSP_PATH/metadata/saml20-idp-hosted.php
fi

sed -i "s/MYORGNAME/$MEMBER_ORG/g" $SSP_PATH/metadata/saml20-idp-hosted.php
sed -i "s/MYORGDISPLAYNAME/$MEMBER_ORGDISPLAY/g" $SSP_PATH/metadata/saml20-idp-hosted.php
sed -i "s|MYORGURL|$MEMBER_ORGURL|g" $SSP_PATH/metadata/saml20-idp-hosted.php

sed -i "s/'metadata.sign.enable' => false,/'metadata.sign.enable' => true,/g" $SSP_PATH/config/config.php
sed -i "s/'metadata.sign.algorithm' => null,/'metadata.sign.algorithm' => 'http:\/\/www.w3.org\/2001\/04\/xmldsig-more#rsa-sha256',/g" $SSP_PATH/config/config.php


if grep "logouttype" $SSP_PATH/metadata/saml20-idp-hosted.php > /dev/null; then
	echo "found existing logout type. skip configuration"
else
	sed -i "/'host' => '__DEFAULT__',/a\  	'logouttype' => 'iframe'," $SSP_PATH/metadata/saml20-idp-hosted.php
fi

echo ""

########################## configuring Consent module
echo "[Consent setup] it converts the default Consent module into that of KAFE generated"

if [ -d $SSP_PATH/modules/consent ]; then
	rm -rf $SSP_PATH/modules/consent
fi

wget https://github.com/coreen-kafe/consent/archive/master.zip
unzip master.zip -d $SSP_PATH/modules
mv $SSP_PATH/modules/consent-master $SSP_PATH/modules/consent

rm -rf master.zip

touch $SSP_PATH/modules/consentAdmin/enable
cp $SSP_PATH/modules/consentAdmin/config-templates/*.php $SSP_PATH/config

POSTFIX="simplesaml"
REDIRECT_URL=$MEMBER_IDPURL$POSTFIX

sed -i "s/DBHOST/localhost/g" $SSP_PATH/config/module_consentAdmin.php
sed -i "s/DBNAME/consent/g" $SSP_PATH/config/module_consentAdmin.php
sed -i "s/USERNAME/$SQL_DB_USER/g" $SSP_PATH/config/module_consentAdmin.php
sed -i "s/PASSWORD/$SQL_DB_PASS/g" $SSP_PATH/config/module_consentAdmin.php
sed -i "s|http:\/\/www.wayf.dk|$REDIRECT_URL|g" $SSP_PATH/config/module_consentAdmin.php
sed -i "s/'authority' => 'saml2'/'authority' => 'kafe-userpass'/g" $SSP_PATH/config/module_consentAdmin.php
echo ""

########################## configuring statistics module
echo "[Consent setup] it converts the default statistics module into that of KAFE generated"

if [ -d $SSP_PATH/modules/statistics ]; then
        rm -rf $SSP_PATH/modules/statistics
fi

wget https://github.com/coreen-kafe/statistics/archive/master.zip
unzip master.zip -d $SSP_PATH/modules
mv $SSP_PATH/modules/statistics-master $SSP_PATH/modules/statistics

rm -rf master.zip

echo ""



########################## KAFE theme
echo "[Theme setup] it overwrites a new KAFE theme. Make sure that your organizational BI(logo) should be placed in "$(pwd)"/images folder."

sed -i "s|https://www.your.org|${MEMBER_IDPURL%/*}|g" $SSP_PATH/modules/kafe/themes/coreen/core/loginuserpass.php
sed -i "s|https://www.your.org|${MEMBER_IDPURL%/*}|g" $SSP_PATH/templates/includes/footer-coreen.php
sed -i "s|MAIN_ADMIN|$SSP_ADMIN_MAIL|g"  $SSP_PATH/modules/kafe/themes/coreen/core/loginuserpass.php


if [ -f ./images/$MEMBER_ORGIMG ]; then
	sed -i "s|images/kreonet_logo.gif|images/$MEMBER_ORGIMG|g" $SSP_PATH/modules/kafe/themes/coreen/core/loginuserpass.php
        sed -i "s|images/kreonet_logo.gif|images/$MEMBER_ORGIMG|g" $SSP_PATH/modules/kafe/themes/coreen/core/logout-iframe.php
	cp ./images/$MEMBER_ORGIMG $SSP_PATH/www/resources/coreen/images/
else
	echo "[Warning] Your organizational BI is not found!! place "$MEMBER_ORGIMG" in "$(pwd)"/images first [Enter]"
	read enter
fi

echo ""

############################ Security configuration
echo "[Security setup] It enforces the KAFE technical profile regarding SSP configuration. \
Security setup is also included in the profile."

sed -i "s/'admin.protectindexpage' => false/'admin.protectindexpage' => true/g"  $SSP_PATH/config/config.php
sed -i "s/'admin.protectmetadata' => false/'admin.protectmetadata' => true/g"  $SSP_PATH/config/config.php
sed -i "s/'errorreporting' => false/'errorreporting' => true/g"  $SSP_PATH/config/config.php
sed -i "s/'showerrors' => false/'showerrors' => true/g"  $SSP_PATH/config/config.php
#sed -i "s/'session.cookie.secure' => false/'session.cookie.secure' => true/g"  $SSP_PATH/config/config.php
#sed -i "s/'session.phpsession.httponly' => false/'session.phpsession.httponly' => true/g"  $SSP_PATH/config/config.php
sed -i "s/'trusted.url.domains' => null/'trusted.url.domains' => array()/g"  $SSP_PATH/config/config.php
sed -i "s|//'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'|'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'|g"  $SSP_PATH/config/authsources.php
sed -i "s|//'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'|'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'|g"  $SSP_PATH/metadata/saml20-idp-hosted.php

if grep "'scope' => array('$META_SCOPE'),"  $SSP_PATH/metadata/saml20-idp-hosted.php > /dev/null; then
        echo "found existing metascope setup. skip configuration"
else
	sed -i "/'userid.attribute' => 'uid',/a\  	'scope' => array('$META_SCOPE'),"  $SSP_PATH/metadata/saml20-idp-hosted.php
fi

if grep "'attributes' => array("  $SSP_PATH/metadata/saml20-idp-hosted.php > /dev/null; then
	echo "found exsiting attributes setup. skip configuration"
else
	sed -i "/'userid.attribute' => 'uid',/a\  	'attributes' => $KAFE_ATTR,"  $SSP_PATH/metadata/saml20-idp-hosted.php		
fi

sed -i "s|__DYNAMIC:1__|$META_ENTITYID|g"  $SSP_PATH/metadata/saml20-idp-hosted.php


############################ Configuration to support R&D Categories
echo "[R&S category support] It enables REFEDS R&S categories."

if [ $KAFE_RS_CATEGORY = "yes" ]; then
    wget https://github.com/coreen-kafe/entitycategories/archive/master.zip
    unzip master.zip -d $SSP_PATH/modules
    mv $SSP_PATH/modules/entitycategories-master $SSP_PATH/modules/entitycategories
    rm -rf master.zip

    sed -i -e "/\/* Add a entitycategories below/r rnscat.template" $SSP_PATH/config/config.php
fi

############################ Default SP configuration for testing
echo "[SP metadata configuration] It sets a default SP (https://testssp.kreonet.net/) metadata."

SP_ENTITY_ID="https://testssp.kreonet.net/sp/simplesamlphp"
HASHVAL=`echo -n "$SP_ENTITY_ID" | md5sum | awk '{print $1}'`

if grep "$HASHVAL" $SSP_PATH"/metadata/saml20-sp-remote.php" > /dev/null; then
        echo "found existing test-sp configuration. erasing."
        sed -i "/#Begin $HASHVAL/, /#End $HASHVAL/d" $SSP_PATH"/metadata/saml20-sp-remote.php"
fi

sed -i "\$a#Begin $HASHVAL\\" $SSP_PATH"/metadata/saml20-sp-remote.php"
sed -i "/#Begin/r testmeta.template" $SSP_PATH"/metadata/saml20-sp-remote.php"
sed -i "\$a#End $HASHVAL\\" $SSP_PATH"/metadata/saml20-sp-remote.php"

############################ logrotate configuration

if [ -f /etc/logrotate.conf ]; then
	echo "[logroate configuration] It sets logrotate.conf so as to keep compressed log files for 1 year"
	sed -i "s/rotate 4/rotate 52/g" /etc/logrotate.conf
	sed -i "s/#compress/compress/g" /etc/logrotate.conf
fi


echo ""
echo "completed"

echo "[NOTE] Please restart this server!!"
