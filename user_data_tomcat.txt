#!/bin/bash
sudo yum -y install tomcat.noarch
sudo yum -y install tomcat-admin-webapps.noarch
sudo yum -y install tomcat-webapps.noarch
sudo yum -y install tomcat-lib.noarch
sudo service tomcat start