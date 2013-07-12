#tested with Centos6.4 run as root
export http_proxy=http://proxy.micron.com:8080
echo "proxy=http://proxy.micron.com:8080" >> /etc/yum.conf

yum install ruby
yum install rubygems
gem install open4
gem install net-ssh
gem install jenkins_api_client

yum install openssl_devel

wget http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/Percona-Server-shared-55-5.5.30-rel30.2.502.rhel6.x86_64.rpm
wget http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/Percona-Server-server-55-5.5.30-rel30.2.502.rhel6.x86_64.rpm
wget http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/Percona-Server-client-55-5.5.30-rel30.2.502.rhel6.x86_64.rpm
wget http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/Percona-Server-devel-55-5.5.30-rel30.2.502.rhel6.x86_64.rpm
rpm -ivh *.rpm
rm *.rpm

mkdir -p .ssh
scp jenkins@$JENKINS_MASTER_IP:/home/jenkins/.ssh/id_rsa.pub .ssh/
scp jenkins@$JENKINS_MASTER_IP:/home/jenkins/.ssh/id_rsa .ssh/
cat .ssh/id_rsa.pub > .ssh/authorized_keys
chmod 700 .ssh
chmod 640 .ssh/authorized_keys
