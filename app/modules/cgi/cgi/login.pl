#!/usr/bin/perl -w

use strict;
use warnings;

use CGI;
use CGI::Session;
use CGI::Template;

my $request = new CGI();
my $template = new CGI::Template();

my $session = new CGI::Session("id:md5", $request, {Directory=>'/tmp'});
if ($session->param("user_name")) {
  print $request->redirect("profile.pl");
  exit 0;
}

print $template->header(-cookie => $session->cookie);
print $template->content();
