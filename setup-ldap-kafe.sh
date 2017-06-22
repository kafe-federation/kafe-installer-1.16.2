#!/bin/sh

source ./config.sh
source ./config-ldap.sh

echo "[Modifying Auth:source] updating auth source from sql to ldap"

if grep "$SSP_AUTHSOURCE_PREFIX-userpass" $SSP_PATH/config/authsources.php > /dev/null; then
    echo "found existing auth:source:sql configuration. deleting"
    sed -i "/'$SSP_AUTHSOURCE_PREFIX-userpass' => array(/,+5d" $SSP_PATH/config/authsources.php
else
    echo "not found existing auth:source:sql configuration. halting"
    exit;
fi

echo "now updating authsources.php"
sed -i "/config = array(/r ldap.template"  $SSP_PATH/config/authsources.php
sed -i "s/PREFIX/$SSP_AUTHSOURCE_PREFIX/" $SSP_PATH/config/authsources.php



sed -i "/URN Prefixces/, +61d" $SSP_PATH/config/config.php
sed -i "/'authproc.idp' => array(/r ldapcfg.template" $SSP_PATH/config/config.php
sed -i "s/'auth' => '$SSP_AUTHSOURCE_PREFIX-userpass',/'auth' => '$SSP_AUTHSOURCE_PREFIX-ldap',/" $SSP_PATH/metadata/saml20-idp-hosted.php
sed -i "/'authproc' => array(/,+10d" $SSP_PATH/metadata/saml20-idp-hosted.php

echo "Ok. completed"


