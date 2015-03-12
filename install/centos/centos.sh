#tested with Centos6.3 run as root

#Our proxy
#export http_proxy=http://proxy.micron.com:8080
#echo "proxy=http://proxy.micron.com:8080" >> /etc/yum.conf
export http_proxy=http://proxy.micron.com:8080
export https_proxy=http://proxy.micron.com:8080

#Install
yum -y install ruby
yum -y install rubygems
cd rubygems-2.0.3
ruby setup.rb
gem install open4
gem install net-ssh
cd ..

sudo yum install -y gcc ruby-devel libxml2 libxml2-devel libxslt libxslt-devel
gem install jenkins_api_client

#wget -r -l 1 -nd -A rpm -R "*debuginfo*" http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/
yum -y remove mysql mysql-devel mysql-libs

yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm

yum install -y Percona-Server-shared-55
yum install -y Percona-Server-client-55
yum install -y Percona-Server-server-55
yum install -y Percona-Server-devel-55


chkconfig mysql off
service mysql stop
