#!/bin/sh
$HOME/miops/server/bin/ops_accepter.pl
$HOME/miops/server/bin/ops_trigger.pl
echo "add entry in /etc/rc.local"
