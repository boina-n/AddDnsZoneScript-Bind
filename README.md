# AddDnsZoneScript-Bind

Developped by Olivier BRUN

#### Script to manage DNS Zone creation with Bind9  

Using zone creation scripts.
-------------
1. Introduction :  
  This tool has been developped to help DNS administrators to add new zones/domains on their authoritative servers based on BIND.

    As a prerequisite, we recommend you to read the DNS general document from the DNS Skill Center : "DNS_Internet_Orange_Group.docx".  

    Starting from a domain name and a template on a name server, it modifies and creates the local configuration files and restarts the service. In parallel, it does the same job remotely on the second name server.  

    Name server where script is executed will be called "primary". The second name server will be "secondary".

1. Usage :  
  ./addzone.sh -d your_domain  

  Every parameters specific to your DNS architecture (server names and IP addresses, path) have been exported to the includes.cfg files. Do not forget to edit this file before using the script.

1. Prerequisites :
   ssh need to be operational between the name servers. It means the primary name server must be able to connect (ssh) and transfer (scp) to the secondary.

4. User manual :  
  The following actions must be done using root :
  - Copy addzone.sh and includes.cfg files to your local directory.
  - Check that addzone.sh script has execute permissions (otherwise add execution rights to the files (chmod +x addzone.sh)).
  - Edit includes.cfg
  - Run the script : ./addzone.sh -d your_zone
  .   

5. addzone.sh :  
  Every changes are done locally on the primary server. Then the files are sent the the secondary and slaves (if any) using scp.

6. Conclusion  
  To be effective, please always use the script from the same name server (primary).
  The zone/domain is created from a template with minimal information (SOA and NS records). After using the script, you will probably need to edit the db file to add additional records (CNAME, A, etc.).
  On a master/slave configuration, every change to a zone will be automatically transfered from master to slave. But on a master/master configuration while making a change on a the primary name server, do not forget to do the same on the second one.

  Thanks to the Orange Kenya teams who provided us with the first version of the script.

7. Changelog

Version 2.2 :
   - Bug fix, in case of the SLAVES_LIST is empty.
   - Bug fix, when the autozones.conf file is transfered to remote servers ("" missing).
   - Change in the includes file name : includes.cfg instead of includes.sh.
   - Change in the README.txt file.

Version 2.3 :
   - Bug fix, in case of a MASTERS_LIST or SLAVES_LIST > 2.
