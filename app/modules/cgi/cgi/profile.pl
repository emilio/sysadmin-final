#!/usr/bin/perl -w
use lib '/etc/sysadmin-app/lib';
use strict;
use warnings;

use CGI;
use CGI::Session;
use CGI::Template;
use HTML::Entities;
use Email::Valid;

use Api::Client;

my $request = new CGI();
my $template = new CGI::Template();
my $error = "";

my $session = new CGI::Session("id:md5", $request, {Directory=>'/tmp'});
my $user_name = $session->param("user_name");
my $login_token = $session->param("login_token");

my $api_client = new Api::Client();

# Should be logged in, but could be trying now via POST
if (!$user_name or !$login_token) {
  $user_name = $request->param("user_name");
  my $password = $request->param("password");

  if ($request->request_method ne "POST" or !$user_name or !$password) {
    print $request->redirect("login.pl");
    exit 0;
  }

  my ($correct_login, $token) = $api_client->check_login($user_name, $password);
  if (!$correct_login) {
    $template->error("Login error, re-check your credentials");
  }

  $session->param("user_name", $user_name);
  $session->param("login_token", $token);
  $login_token = $token;
}

# This is just an extra safety check
if (!$api_client->check_login_token($user_name, $login_token)) {
  $session->clear(["user_name", "login_token"]);
  $template->error("invalid login token");
}

my $action;
if ($request->request_method eq "POST" and ($action = $request->param("action"))) {
  # Delete the user if he requests so
  if ($action eq "Delete account") {
    $api_client->delete_user($user_name);
    print $request->redirect("logout.pl");
    exit 0;
  }

  if ($action eq "Update profile") {
    my $email = $request->param("email");
    my $address = $request->param("address");

    if (!$email or !$address) {
      $error = "Empty email or address.";
    } elsif (!Email::Valid->address($email)) {
      $error = "Invalid email address";
    } elsif (!$api_client->update_user_data($user_name, $email, $address)) {
      $error = "Unable to update the user data";
    }
  }

  if ($action eq "Update password") {
    my $password = $request->param("password");
    my $password_confirmation = $request->param("password_confirmation");

    if (!$password or !$password_confirmation) {
      $error = "Missing password";
    } elsif ($password ne $password_confirmation) {
      $error = "Password mismatch";
    } elsif (!$api_client->update_user_password($user_name, $password)) {
      $error = "Unknown error while updating the password";
    } else {
      my ($correct_login, $new_token) = $api_client->check_login($user_name, $password);
      if (!$correct_login) {
        $error = "Invalid login after changing password, something is really fucked up";
      } else {
        $session->param("login_token", $new_token);
      }
    }
  }

  if ($action eq "Update features") {
    my $personal_page_enabled = $request->param("features_personal_page");
    if (!$api_client->set_feature($user_name, "personal_page", $personal_page_enabled)) {
      $error .= "Error " . ($personal_page_enabled ? "enabling" : "disabling") . " personal page.";
    }
  }
}

print $template->header(-cookie => $session->cookie);
my %data = $api_client->get_user_data($user_name);

my $success = "";
if ($request->request_method eq "POST" and
    $action and
    (not $error or length($error) == 0)) {
  $success = "Success!";
}

print $template->content(
  ERROR => $error,
  SUCCESS => $success,
  EMAIL => $data{"email"},
  ADDRESS => encode_entities($data{"address"}),
  USER_NAME => $user_name,
);
