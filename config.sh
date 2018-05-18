#!/bin/sh
######################## configuration #############################
## simpleSAMLphp configuration
# The role name of system administrator; do not set real name of the administrator
SSP_ADMIN_NAME=Administrator

# Email address of the administrator; KAFE considers it as a role information 
# (not personal information)
SSP_ADMIN_MAIL=adminemail@yourorg.ac.kr

# Password of the administrator; the password is used for simpleSAMLphp Web login
SSP_ADMIN_PASS=yourpasswordhere

# Path for simpleSAMLphp
SSP_PATH="/var/simplesamlphp"

# This identity-provider server's IP address can be either a public or a private.
# Currently, the available option is the public only.
IP_TYPE=public

# set ldap or sql based on the type of backend database
BACKEND_DB="sql"


# Configuration for Mysql database; used only for testing purpose. SQL_DB_USER should
# be "root".
SQL_DB_NAME=user_db_test
SQL_DB_USER=root
SQL_DB_PASS=yourdbpasswordhere


########################## skip from here ############################
# for Oracle DB
# SQL_TYPE oracle/others
SQL_TYPE=others
# DB
ORACLE_DB_USERNAME=oracleuser
ORACLE_DB_PASSWORD=oraclepass
ORACLE_TABLENAME=oracletable

ORACLE_SRV_ADDR=10.1.1.1
ORACLE_SRV_PORT=3128
ORACLE_SID_NAME=yoursid
# table field(attribute) name
ORACLE_FIELD_USERNAME=oracle_field_username
ORACLE_FIELD_PASSWORD=oracle_field_password
ORACLE_FIELD_DISPLAYNAME=oracle_field_displayname
ORACLE_FIELD_MAIL=oracle_field_email
ORACLE_FIELD_EPA=oracle_field_affiliation	
########################### to here ####################################

## Apache configuration
# The server name should be a domain name. KAFE rejects this identity provider if the 
# server name is set to an IP address. An IP address would be okay only for testing purpose.
SERVER_NAME="1.5.1.1"

# The location of this Identity provider; used for generating a self-signed certification
SSL_CITYNAME="City"

# The name of this organization; used for generating a self-signed certification
SSL_COMPANYNAME="Schoolforshort"

# The department of this identity provider; used for generating a self-signed certification
SSL_DEPTNAME="Information Service Affairs Team"

## Metadata configuration
# Full name of your organization
MEMBER_ORG="YOUR ORG FULL NAME"

# Full name of your organization
MEMBER_ORGDISPLAY=$MEMBER_ORG

# The URL of your organization
MEMBER_ORGURL="http://www.yourorg.ac.kr/"

# The URL of this Identity Provider
MEMBER_IDPURL="https://"$SERVER_NAME"/"

# The BI of your organization; KAFE generates the following two logo images
MEMBER_ORGIMG="yourorg_logo.gif"

# The scope of this Identity Provider; the scope is generally a primary domain of the organization
META_SCOPE="yourorg.ac.kr"

# Full name of this ogranization
ATTRIBUTE_ORGNAME=$MEMBER_ORG

# Fully qualified domain name of this organization
ATTRIBUTE_SCHACHOMEORG="yourorg.ac.kr"

# The scope of eduPersonScopedAffiliation; DO NOT change the following
ATTRIBUTE_EPSCOPEDAFFILIATION=$META_SCOPE

# eduPersonEntitlement; DO NOT change the following. Scoped affiliation and the ePE can not be used at the same time
ATTRIBUTE_EPENTITLEMENT="urn:mace:dir:entitlement:common-lib-terms"

# attributes provided by this Identity Provider; KAFE recommend the use of following user attributes
KAFE_ATTR="array('uid','surname','givenName','displayName','mail','eduPersonAffiliation','eduPersonEntitlement', 'organizationName','eduPersonPrincipalName','eduPersonScopedAffiliation','schacHomeOrganization', 'schacHomeOrganizationType')"

# add or not research and scholarship category
KAFE_RS_CATEGORY=yes
KAFE_EDUGAIN=yes

# the name of federation; initially, all organizations have to join a test federation
KAFE_FEDMETANAME="KAFE-testfed"
META_DIR="metadata-kafe-test"

################### Additional configuration ########################
###################### DO NOT modify below ##########################
# DO NOT modify MEMBER_ENTITYID
echo $MEMBER_IDPURL |grep '/$' > /dev/null
if [ $? -eq 0 ]; then
        META_ENTITYID=$MEMBER_IDPURL"idp/simplesamlphp"
else
        META_ENTITYID=$MEMBER_IDPURL"/idp/simplesamlphp"
fi

echo $MEMBER_IDPURL |grep '/$' > /dev/null
if [ $? -eq 0 ]; then
        CRON_URL=$MEMBER_IDPURL"simplesaml/module.php/cron/cron.php"
else
        CRON_URL=$MEMBER_IDPURL"/simplesaml/module.php/cron/cron.php"
fi

CRON_KEY=$(tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom | dd bs=32 count=1 status=none)
