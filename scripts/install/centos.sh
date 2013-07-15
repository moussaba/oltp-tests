#tested with Centos6.4 run as root
export http_proxy=http://proxy.micron.com:8080
echo "proxy=http://proxy.micron.com:8080" >> /etc/yum.conf

yum install ruby
yum install rubygems
gem install open4
gem install net-ssh

yum install openssl_devel
#rpm -Uhv http://www.percona.com/downloads/percona-release/percona-release-0.0-1.x86_64.rpm

yum remove mysql mysql-devel mysql-libs
wget -r -l 1 -nd -A rpm -R "*debuginfo*"  \
http://www.percona.com/redir/downloads/Percona-Server-5.5/Percona-Server-5.5.30-30.2/RPM/rhel6/x86_64/

rpm -ivh Percona-Server-shared-55-*.rpm
rpm -ivh Percona-Server-client-55-*.rpm
rpm -ivh Percona-Server-server-55-*.rpm
rpm -ivh Percona-Server-devel-55-*.rpm

rm -f *.rpm

mkdir -p /home/jenkins/.ssh
scp jenkins@$JENKINS_MASTER_IP:/home/jenkins/.ssh/id_rsa.pub /home/jenkins/.ssh/
scp jenkins@$JENKINS_MASTER_IP:/home/jenkins/.ssh/id_rsa /home/jenkins/.ssh/
cat /home/jenkins/.ssh/id_rsa.pub > /home/jenkins/.ssh/authorized_keys
chmod 700 /home/jenkins/.ssh
chmod 640 /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh
