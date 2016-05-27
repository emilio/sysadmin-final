#!/usr/bin/perl -w

use strict;
use warnings;

use CGI;
use CGI::Template;
use CGI::Session;

my $request = new CGI();

my $session = new CGI::Session("id:md5", $request, {Directory=>'/tmp'});
$session->clear(["user_name", "login_token"]);

print $request->redirect("login.pl");
