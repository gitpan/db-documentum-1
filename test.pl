#!/usr/local/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; $numtests = 12 ; print "1..$numtests\n"; }
END {print "not ok 1 # Modules load.\n" unless $loaded;}
use Db::Documentum qw(:all);
use Db::Documentum::Tools qw(:all);
$loaded = 1;
print "ok 1 # Modules load.\n";

######################### End of black magic.

$counter = 2;
$success = 1;

if (! $ENV{'DMCL_CONFIG'}) {
	print "Enter the path to your DMCL_CONFIG file: "; chomp ($dmcl_config = <STDIN>);
	if (-r $dmcl_config) { $ENV{'DMCL_CONFIG'} = $dmcl_config; }
	else { die "Can't find DMCL_CONFIG '$dmcl_config': $!.  Exiting."; }
}

print "Using '$ENV{'DMCL_CONFIG'}' as client config.\n";
print "Docbase name: "; chomp ($docbase = <STDIN>);
print "Username: "; chomp ($username = <STDIN>);
print "Password: "; chomp ($password = <STDIN>);

# Here's the bulk of our test suite.
print "\n\nTesting Db::Documentum module...\n";
# Test DM client connect.
do_it("connect,$docbase,$username,$password",NULL,"dmAPIGet",
		"DM client connection");
# Test DM object creation.
do_it("create,c,dm_document",NULL,"dmAPIGet","DM object creation");
# Test DM set
do_it("set,c,last,object_name","Perl Module Test","dmAPISet",
		"DM attribute set");
# Test DM exec
do_it("link,c,last,/Temp",NULL,"dmAPIExec","DM object link");
# Test DM save
do_it("save,c,last",NULL,"dmAPIExec","DM save.");
# Test DM disconnect
do_it("disconnect,c",NULL,"dmAPIExec","DM disconnect.");

###
# Here is the Tools.pm test suite
###

print "\n\nTesting Db::Documentum::Tools module...\n";

# Test dm_LocateServer
$result = dm_LocateServer($docbase);
tally_results($result,"dm_LocateServer","Locate Docbase server");

# Test dm_Connect
$result = dm_Connect($docbase,$username,$password);
tally_results($result,"dm_Connect","Connection");

# Test dm_CreatePath
$result = dm_CreatePath('/Temp/Db-Documentum-Test');
tally_results($result,"dm_CreatePath","Create a folder");

# Test dm_CreateType
%ATTRS = (cat_id   =>  'CHAR(16)',
          locale   =>  'CHAR(255) REPEATING');
$result = dm_CreateType("my_document","dm_document",%ATTRS);
tally_results($result,"dm_CreateType","Create new object type");

# Test dm_CreateObject
$delim = $Db::Documentum::Tools::Delimiter;
%ATTRS = (object_name =>  'Perl Module Tools Test Doc',
          cat_id      =>  '1-2-3-4-5-6-7',
          locale      =>  'Virginia'.$delim.'California'.$delim.'Ottawa');
$result = dm_CreateObject("my_document",%ATTRS);
tally_results($result,"dm_CreateObject","Create new object");
warn dm_LastError("c","3","all") unless dmAPIExec("link,c,$result,'/Temp/Db-Documentum-Test'");
warn dm_LastError("c","3","all") unless dmAPIExec("save,c,$result");

dmAPIExec("disconnect,c");

# Test Summary
if ($success == $numtests) {
	print "\nAll tests completed successfully.\n";
} else {
	print "\nAll tests complete.  ", $numtests - $success, " of $numtests tests failed.\n";
	print "If tests fail and the above error output is not helpful check your server logs.\n";
}
exit;


sub do_it {
	my($method,$value,$function,$description) = @_;
	my($result);

	if ($function eq 'dmAPIGet') {
		$result = dmAPIGet($method);
	} elsif ($function eq 'dmAPIExec') {
		$result = dmAPIExec($method);
	} elsif ($function eq 'dmAPISet') {
		$result = dmAPISet($method,$value);
	} else {
		die "$0: Unknown function: $function";
	}

    tally_results($result,$function,$description);
}


sub tally_results {
    my ($r,$f,$d) = @_;

    if (! $r) { print "not "; }
	print "ok $counter # $d [$f()]\n";

	if ($r) {
		$success++;
	} else {
		print dm_LastError("c","3","all");
	}
	$counter++;
}


