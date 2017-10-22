#!/bin/bash
domain=0

#############################################################################################################
# This script must be executed on a master server. Please check the masters and slaves lists in includes.sh #
#############################################################################################################

# Include file to remove out all the definitions for portability
PWD=$(pwd)
. "$PWD/includes.cfg"

# Check the script usage
if [ $# -lt 2 ]; then
        echo "Usage: $0 -d [DOMAINNAME] "
        exit 21
fi

# Check the parameters
while getopts  "d:" opt
do
  case ${opt} in
            d) domain=${OPTARG} ;;
            *) echo "Usage: $0 -d [DOMAINNAME] "
                exit 21;;
   esac
done

# Check that domain is not null
if [ $domain = 0 ];then
        echo "Error : Domain name missing"
        exit 21
fi

echo "..........Starting $domain creation"

# Check if the zone already exist in the configuration file
if  grep \"$domain\" $NAMED_CONF_PATH > /dev/null  ; then
    echo "Error : Domain $domain already exists, please try another domain"
    exit 21
fi

# Check if the db file already exist
if [ -e "$NAMED_DB_PATH/db.$domain" ]; then
        echo "Error : There is another copy of the db file for the domain $domain"
        exit 21
fi

# Update and copy the configuration file
echo "..........Updating autozones.conf file on localhost"
echo "
# $domain master zone
zone \"$domain\" {
        type master;
        file \"master/db.$domain\";
};" >> $NAMED_CONF_PATH

# Create serial number to insert in db file
echo "..........Preparing the serial number"
mydate=`date +%Y%m%d`
serial=$mydate'1'

#getting first master
FIRST_MASTER_NAME=$(echo $MASTERS_LIST | cut -d ':' -f1 );
FIRST_MASTER_IP=$(echo $MASTERS_LIST | cut -d ';' -f1 | cut -d ':' -f2 );

# Create the template db file using the serial number created above
echo "..........Creating the zone file and replacing its serial number on localhost"
#Creating SOA record
echo "
\$ttl $TTL
@       IN      SOA     $FIRST_MASTER_NAME.$domain. registrar.$domain. (
                $serial         ; serial
                $REFRESH        ; refresh
                $RETRY          ; retry
                $EXPIRE         ; expire
                $N_TTL    ); negative TTL    " >> $NAMED_DB_PATH/db.$domain

#Concatenating MASTERS et SLAVES LIST
if [ ! -z $SLAVES_LIST ];then
        NS_LIST="$MASTERS_LIST;$SLAVES_LIST";
else
        NS_LIST="$MASTERS_LIST";
fi

#Creating NS records
echo $NS_LIST | sed 's/;/\n/g' | while read ns
do
        NS_NAME=$(echo $ns | cut -d ':' -f1 );
        echo "  IN      NS      $NS_NAME" >> $NAMED_DB_PATH/db.$domain;
done;

#Creating A Records for NS
echo $NS_LIST | sed 's/;/\n/g' | while read ns
do
        NS_NAME=$(echo $ns | cut -d ':' -f1 );
        NS_IP=$(echo $ns | cut -d ';' -f1 | cut -d ':' -f2 );
        echo "$NS_NAME  IN      A       $NS_IP" >> $NAMED_DB_PATH/db.$domain;
done;

# Change the owner of the db file
chown $DNS_USER $NAMED_DB_PATH/db.$domain



#########################################################################################
# Prerequisite : remote access to the other name server using SSH need to be configured #
#########################################################################################

# List all the authoritative DNS servers
echo $MASTERS_LIST | sed 's/;/\n/g' | while read ns
do
        NS_IP=$(echo $ns | cut -d ':' -f2 );
        MASTERS_IP="${MASTERS_IP}$NS_IP;";
        echo $MASTERS_IP > /tmp/.masters_ip;
done
MASTERS_IP=$(cat /tmp/.masters_ip);
#rm /tmp/.masters_ip;

# Copy the configuration file to masters
echo $MASTERS_LIST | cut -s -d ';' -f2- | sed 's/;/\n/g' | while read ns
do
	NS_IP=$(echo $ns | cut -d ':' -f2 );
        echo "..........Securely copy the configuration file to $NS_IP master server"
        scp -q $NAMED_CONF_PATH $NS_IP:$NAMED_CONF_PATH;
        echo "..........Securely copy the db zone file to the $NS_IP master server"
        scp -q "$NAMED_DB_PATH/db.$domain" $NS_IP:$NAMED_DB_PATH;
        echo "..........Restarting the name service on $NS_IP "
        ssh -nq $NS_IP "chown $DNS_USER $NAMED_DB_PATH/db.$domain && $RNDC_PATH reload";
done;

# Copy the configuration file to slaves
if [ ! -z $SLAVES_LIST ]
then
    echo $SLAVES_LIST | sed 's/;/\n/g' | while read ns
    do
        NS_IP=$(echo $ns | cut -d ':' -f2 );
        echo "..........Securely copy the configuration file to $NS_IP slave server"
        ssh -nq $NS_IP "echo -e \"\n# $domain slave zone\nzone \\\"$domain\\\" {\n  type slave;\n   masters { $MASTERS_IP };\n      file \\\"slave/db.$domain\\\";\n};\" >> $NAMED_CONF_PATH"
        echo "..........Restarting the name service on $NS_IP "
	ssh -nq $NS_IP "$RNDC_PATH reload"
    done;
fi

echo "..........Restarting the name service on localhost"
$RNDC_PATH reload

echo "..........Zone added successfully"
echo "..........Do not forget to add your records to the db files"
