#!/usr/bin/perl
use Expect;
use Test::Simple tests=>1;
#use SendMail;
use DBI;
use JSON;
use MIME::Base64;

my $pass = decode_base64($ARGV[0]);
print $pass."\n";
