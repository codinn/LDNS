# ldns-apple

https://github.com/Homebrew/homebrew-core/blob/master/Formula/ldns.rb
```
libtoolize -ci --force
autoreconf -fi
./configure CFLAGS="-mmacosx-version-min=10.13" CPPFLAGS="-mmacosx-version-min=10.13" LDFLAGS="-mmacosx-version-min=10.13" --prefix=$(PWD)/build/dist --with-ssl="$(PWD)/../openssl/bin/MacOSX10.15-x86_64.sdk"
make install
```
