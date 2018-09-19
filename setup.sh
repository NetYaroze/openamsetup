#!/bin/bash

set -e
set -x

JDK=jdk-8u131-linux-x64
AM=13.5.0
AGENT4=4.1.0
J2EE_AGENT=Tomcat-v6-Agent_3.5.1
TOMCAT=apache-tomcat-8.0.33
PWFILE=~/pw.txt
J2EE_TOMCAT_DIR=~/apache-j2ee
J2EE_ZIP=/staging/$J2EE_AGENT.zip
J2EE_ROOT=~/j2ee_agents
J2EE_TYPE=tomcat_v6_agent

export JAVA_HOME=/usr/java/default/jre

UNZIP='unzip -o'

if [ $1 == 'basic' ]; then
  BASIC=true
  echo 'Basic mode - Setting up basics only'
else
  BASIC=false
  echo 'OpenAM Install mode'
fi

# Echo to an openam.config file which the configurator then uses to configure the OpenAM Instance 
if [ $1 == 'configure' ]; then
  CNF=~/openam.config
  echo "SERVER_URL=http://$('hostname'):8080" > $CNF
  echo "DEPLOYMENT_URI=/openam" >> $CNF
  echo "BASE_DIR=$HOME/openam" >> $CNF
  echo "locale=en_US" >> $CNF
  echo "PLATFORM_LOCALE=en_US" >> $CNF
  echo "AM_ENC_KEY=" >> $CNF
  echo "ADMIN_PWD=cangetin" >> $CNF
  echo "AMLDAPUSERPASSWD=cangetinam" >> $CNF
  echo "COOKIE_DOMAIN=.fr.local" >> $CNF
  echo "ACCEPT_LICENSES=true" >> $CNF
  echo "DATA_STORE=embedded" >> $CNF
  echo "DIRECTORY_SSL=SIMPLE" >> $CNF
  echo "DIRECTORY_SERVER=localhost" >> $CNF
  echo "DIRECTORY_PORT=50389" >> $CNF
  echo "DIRECTORY_ADMIN_PORT=4444" >> $CNF
  echo "DIRECTORY_JMX_PORT=1689" >> $CNF
  echo "ROOT_SUFFIX=o=openam" >> $CNF
  echo "DS_DIRMGRDN=cn=Directory Manager" >> $CNF
  echo "DS_DIRMGRPASSWD=cangetin" >> $CNF


# Pass the openam.config tot the configurator.

  java -jar ~/ssoconfigure/openam-configurator-tool-$AM.jar -f $CNF
  sudo ln -s ~/openam/openam/debug debug
  sudo ln -s /etc/httpd/web_agents/apache24_agent/Agent_001/ ~/agent001

  cd ~/ssoadm
  ./setup -p ~/openam --acceptLicense
 	

  # edit policy xml and import. Pretty basic for now. Set port to '*'. Method is already *
  cp /staging/policy-setup.xml ~
  sed -i "s/SETUP_HOST:SETUP_PORT/$('hostname'):*/g" ~/policy-setup.xml
  ssoadm create-xacml -u amadmin -f ~/pw.txt -e / -X ~/policy-setup.xml

  # Enable message level debug
  ssoadm update-server-cfg -s http://$('hostname'):8080/openam  -u amadmin -f $PWFILE -a com.iplanet.services.debug.level=message

  # Install HTTPD and agent
  if [ -e /etc/httpd ]; then
    sudo service httpd stop
    sudo yum remove httpd -y
    sudo rm -rf /etc/httpd/
    sudo yum install php httpd -y
  fi

  # Add a web agent and a j2ee agent
  mkdir /etc/httpd/web_agents
  mkdir /etc/httpd/web_agents/4
  ssoadm create-agent -u amadmin -f $PWFILE -e / -b apache -t WebAgent -g http://$('hostname'):80 -s http://$('hostname'):8080/openam -a userpassword=cangetin
  ssoadm create-agent -u amadmin -f $PWFILE -e / -b j2ee -t J2EEAgent -g http://$('hostname'):8180/agentapp -s http://$('hostname'):8080/openam -a userpassword=cangetin
  
  # And one for local agent dev build
  ssoadm create-agent -u amadmin -f $PWFILE -e / -b apache-dev -t WebAgent -g http://jcfg-mbp.local:8888 -s http://$('hostname'):8080/openam -a userpassword=cangetin
  

  # Put on both 3.x and 4.x agents for now
  cd /etc/httpd
  sudo unzip /staging/Apache-v2.4-Linux-64-Agent-$AGENT.zip
  sudo mkdir 4
  cd 4
  sudo unzip /staging/Apache_v24_Linux_64bit_$AGENT4.zip

  #Webagent response file
  RSP=~/response.config
  echo "CONFIG_DIR=/etc/httpd/conf" > $RSP
  echo "AM_SERVER_URL=http://$('hostname'):8080/openam" >> $RSP
  echo "AGENT_URL=http://$('hostname'):80" >> $RSP
  echo "AGENT_PROFILE_NAME=apache" >> $RSP
  echo "AGENT_PASSWORD_FILE=$PWFILE" >> $RSP

  #J2EE agent response file
  JRSP=~/j2ee-response.config
  echo "CONFIG_DIR=$J2EE_TOMCAT_DIR/conf" > $JRSP
  echo "AM_SERVER_URL=http://$('hostname'):8080/openam" >> $JRSP
  echo "CATALINA_HOME=$J2EE_TOMCAT_DIR" >> $JRSP
  echo "INSTALL_GLOBAL_WEB_XML=" >> $JRSP
  echo "AGENT_URL=http://$('hostname'):8180/agentapp" >> $JRSP
  echo "AGENT_PROFILE_NAME=j2ee" >> $JRSP
  echo "AGENT_PASSWORD_FILE=$PWFILE" >> $JRSP

  # Unzip J2EE agent files
  rm -rf $J2EE_TOMCAT_DIR
  rm -rf /tmp/$TOMCAT
  cd /tmp
  $UNZIP /staging/$TOMCAT.zip
  mv /tmp/$TOMCAT $J2EE_TOMCAT_DIR
  cp /staging/bin/setenv.sh $J2EE_TOMCAT_DIR/bin
  chmod +x $J2EE_TOMCAT_DIR/bin/*.sh
  cd ~
  rm -rf j2ee_agents
  unzip -o $J2EE_ZIP

  #copy index files
  #sudo cp /staging/index.html /var/www/html/
  #sudo cp /staging/benis.jpg  /var/www/html/
	
  # agentadmin install for both agents
  sudo /etc/httpd/web_agents/apache24_agent/bin/agentadmin --install --useResponse $RSP --acceptLicense
  $J2EE_ROOT/$J2EE_TYPE/bin/agentadmin --install --useResponse $JRSP --acceptLicense

  sudo /etc/httpd/4/web_agents/apache24_agent/bin/agentadmin  --s /etc/httpd/conf/httpd.conf http://$('hostname'):8080/openam http://$('hostname'):80 / apache $PWFILE --acceptLicence

  # Copy webapps to J2EE agent Tomcat
  cp $J2EE_ROOT/$J2EE_TYPE/etc/agentapp.war $J2EE_TOMCAT_DIR/webapps
  cp $J2EE_ROOT/$J2EE_TYPE/sampleapp/dist/agentsample.war $J2EE_TOMCAT_DIR/webapps
  mv $J2EE_TOMCAT_DIR/conf/server.xml $J2EE_TOMCAT_DIR/conf/server.xml.orig
  # Config with non-conflicting ports
  cp /staging/server-j2ee.xml $J2EE_TOMCAT_DIR/conf/server.xml

  # TODO: service for j2ee agent
  ~/apache-j2ee/bin/startup.sh

  sudo cp -r /staging/html/* /var/www/html
  sudo service httpd start
  sudo systemctl enable httpd
  exit 0
fi

#Set the time properly.
cd ~
sudo timedatectl set-timezone Europe/London
#sudo yum -y update
sudo yum -y install unzip telnet net-tools ntp php httpd screen tcpdump tmux lsof strace sysstat openldap-clients
sudo service ntpdate restart

sudo cp /usr/share/doc/tmux*/examples/screen-keys.conf /etc/tmux.conf

# Install Java JDK.
if [ ! -f $JAVA_HOME/bin/java ] && [ ! -z $JDK ]; then
  sudo yum -y install /staging/$JDK.rpm
fi

if [ $BASIC == 'true' ]; then
  echo "Basic only. Exiting"
  exit 0
fi

# Obviously, turning the firewall off and disabling it.
sudo systemctl stop firewalld
sudo systemctl disable firewalld

#If Tomcat exists then stop it, remove its traces and reinstall it. 
if [ ! -z $TOMCAT ]; then
  if [ -d $TOMCAT ]; then
    sudo service tomcat stop
    rm -rf $TOMCAT
    rm -rf $HOME/openam
  fi

  $UNZIP /staging/$TOMCAT.zip
  cp /staging/bin/setenv.sh ~/$TOMCAT/bin
  chmod +x ~/$TOMCAT/bin/*.sh

  if [ ! -z $AM ]; then
    rm -rf $AM
    mkdir $AM
    cd $AM
    OPENAM=OpenAM-$AM
    $UNZIP /staging/$OPENAM.zip
    rm -rf ~/$TOMCAT/webapps/openam*
    cp ~/$AM/openam/$OPENAM.war ~/$TOMCAT/webapps/openam.war
    cd ~

    ln -sf $TOMCAT ~/apache
    sudo cp /staging/bin/tomcat-init.sh /etc/init.d/tomcat
    sudo chmod u+x /etc/init.d/tomcat
    sudo chkconfig --add tomcat
    sudo chkconfig tomcat on
    sudo service tomcat start

    # Tools
    rm -rf $PWFILE
    echo "cangetin" > $PWFILE
    chmod 400 $PWFILE
    rm -rf ~/ssoadm
    mkdir ~/ssoadm
    cd ~/ssoadm
    $UNZIP ~/$AM/openam/SSOAdminTools-$AM.zip
    #ssoconfigure
    rm -rf ~/ssoconfigure
    mkdir ~/ssoconfigure
    cd ~/ssoconfigure
    $UNZIP ~/$AM/openam/SSOConfiguratorTools-$AM.zip
  fi
else
  if [ ! -z $AM ]; then
     echo "$AM specified but no TOMCAT"
     exit 1
  fi
fi

#For agent
sudo setenforce 0
sudo sed -i -e 's/enforcing/disabled/g' /etc/selinux/config


#TODO: policy (import or create?), j2ee agent. SAML IDP/SP init SSO/logout
#Symlinks (debug folders) and more aliases

#Email service
sudo chown -R apache:apache /etc/httpd/4 /etc/httpd/web_agents
sudo chmod 755 /etc/httpd/web_agents /etc/httpd/4


# Copy all shell scripts since /staging/bin inevitably disappears after reboot. Not that these will all work on a VM
cp -R /staging/bin/* ~/bin

# Allow for passwordless SSH between VMs
cp /staging/id_rsa* /home/fr/.ssh
chown fr.fr ~/.ssh/id_rsa*
chmod og-rwx ~/.ssh/id_rsa*

