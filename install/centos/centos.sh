#tested with Centos6.3 run as root

#Our proxy
#export http_proxy=http://proxy.micron.com:8080
#echo "proxy=http://proxy.micron.com:8080" >> /etc/yum.conf

#Install
yum -y install ruby
yum -y install rubygems
gem install open4
gem install net-ssh

sudo yum install -y gcc ruby-devel libxml2 libxml2-devel libxslt libxslt-devel
gem install jenkins_api_client

wget -r -l 1 -nd -A rpm -R "*debuginfo*" http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/
yum -y remove mysql mysql-devel mysql-libs

rpm -ivh Percona-Server-shared-55-*.rpm
rpm -ivh Percona-Server-client-55-*.rpm
rpm -ivh Percona-Server-server-55-*.rpm
rpm -ivh Percona-Server-devel-55-*.rpm

rm -f *.rpm