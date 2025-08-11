# nginx-zig

use zig build nginx

zig 0.14.x

## steps

```bash
uname -a
# Darwin bogon 24.5.0 Darwin Kernel Version 24.5.0: Tue Apr 22 19:48:46 PDT 2025; root:xnu-11417.121.6~2/RELEASE_ARM64_T8103 arm64

zig version
# 0.14.2-dev.3+12306119e
# ^ 0.14.1 should works too

./auto/configure --with-cc="zig cc" --without-pcre2 --without-pcre --without-http_rewrite_module
# took 23s

make
# took 7s

./objs/nginx -V
# nginx version: nginx/1.29.0
# built by clang 19.1.0 (git@github.com:ziglang/zig-bootstrap.git 68372891ef07ba86c5a81791a40c238cc6e1e7f2)
# configure arguments: --with-cc='zig cc' --without-pcre2 --without-pcre --without-http_rewrite_module

```
