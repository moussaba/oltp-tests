cd bin/snappy
autoreconf --force --install
./configure --prefix=/usr
make
make install
mv /usr/lib/libsnappy.* /usr/lib64/

cd ../bin/snzip
./configure --prefix=/usr
make
make install

