#!/usr/bin/perl
use strict;
use Env;
use File::Spec;
my $path_curf = File::Spec->rel2abs(__FILE__);
my ($vol, $path, $file) = File::Spec->splitpath($path_curf);

`cd $path/..; md5sum agent/{bin/*.*,bin/*/*,filter/*,lib/*,plugin/*/*.*,plugin/*.*} tools/deploy/* > $path/aa.md5`;
my $out = `md5sum $path/aa.md5`;
print $out;
unlink("$path/aa.md5");

