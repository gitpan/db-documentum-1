use ExtUtils::MakeMaker;


print "\n\n\nWelcome to the Db::Documentum installation process.\n";
print "---------------------------------------------------\n\n";
print "Please select:\n\n";
print "\t1) to build the module for EDMS98, or\n";
print "\t2) to build the module for Documentum 4i\n";
print "==>";
chomp($ans = <STDIN>);
if ($ans =~ /1/) {
    $dmcl = 'dmcl32.lib';
} else {
    $dmcl = 'dmcl40.lib';
}

unless ($OS = $^O) {
	   require Config;
	   $OS = $Config::Config{'osname'};
}
print "\n\nConfiguring Db::Documentum for $OS...\n\n";

##################################################################
# *** Windows NT users should look here ***
##################################################################
if ($OS =~ /Win/i) {

	# Path to Documentum installation directory.
	$DM_HOME = 'c:\\program files\\documentum';

	# Path to Documentum libraries (dmcl32.lib or dmcl40.lib).
    #
	# *** EDMS 98 ***
	# The dmcl32.lib is probably already in this directory.
	#
	# *** 4i ***
	# The dmcl40.lib can be found on your 4i server in:
	#       <DOCUMENTUM>/share/clients/win/32.
	# I suggest putting it here for simplicity.	
	$DM_LIB = "$DM_HOME\\shared";

	# Path to dmapp.h.
	# dmapp.h is not in DM_HOME/shared by default; I suggest putting it here
	# for simplicity.
	#
	# *** EDMS 98 ***
	# If you are using EDMS 98, you can find dmapp.h on the DocPage Builder CD in:
	#   <cd>:\docpage builder\samples\server\unix\c.
	#
	# *** 4i ***
	# If you are using 4i, you can find dmapp.h on your server's hard drive in:
	#   <DOCUMENTUM>/share/sdk/include.
	#
	$DM_INCLUDE = "$DM_HOME\\shared";

    # get the CPP include and lib paths from the environment
    my $inc = $ENV{INCLUDE};
    $inc = "-I" . join(" -I",split(";",$inc));
    my $lib = $ENV{LIB};
    $lib = "-L" . join(" -L",split(";",$lib));

    warn "No INCLUDE or LIB environment variable found.  You may need to run VCVARS32.BAT" .
         " before running nmake." if (!$inc || !$lib);

    # build all nmake parameters
    $CPP_INCS = $inc;
    $DM_INCLUDE = "-I\"$DM_INCLUDE\"";
	$CPP_LIBS = $lib;
	$DM_CLIENT_LIBS = "-L\"$DM_LIB\" -l$dmcl";
    # Not used for Win32 nmake
	$LD_LIBS = "";
	$DM_RPC_LIBS = "";
	$OS_LIBS = "";
}

##################################################################
# *** Unix users (Solaris, AIX, and HP/UX) should look here ***
##################################################################
elsif ( ($OS =~ /solaris/i) or ($OS =~ /aix/i) or ($OS =~ /hpux/i) ) {

	# The path to your Documentum client installation.
	$DM_HOME = '/usr/local/documentum';

	# If you've organized your Documentum libraries in the standard unix-y
	# bin, lib, include fashion, then you should be all set.  Otherwise you
	# may have to tweak these.

	# Path to documentum client libraries.
	$DM_LIB = "$DM_HOME/lib";

	# Path to directory where dmapp.h lives.
	$DM_INCLUDE = "-I$DM_HOME/include";

	$DM_CLIENT_LIBS = "-L$DM_LIB -ldmapi -ldmupper -ldmlower -ldmcommon -ldmupper -lcompat";
	$DM_RPC_LIBS = "-L$DM_LIB -lnwrpc -lnwstcp";
	$OS_LIBS = "-lsocket -lnsl -lintl";
	$CPP_LIBS = "-lC";
	$LD_LIBS = "-ldl";
	$CPP_INC = "";
}

##################################################################
# Otherwise you're out of luck.  Documentum doesn't support you, so how
# can we?
##################################################################
else {
	die "$OS is not a supported platform for Db::Documentum (or for Documentum in general).\n";
}

# print config summary
print "Config summary:\n\n";
print "DM_INCLUDE=\n\t$DM_INCLUDE\n\n";
print "CPP_INCS=\n\t$CPP_INCS\n\n";
print "DM_CLIENT_LIBS=\n\t$DM_CLIENT_LIBS\n\n";
print "CPP_LIBS=\n\t$CPP_LIBS\n\n";
print "LD_LIBS=\n\t$LD_LIBS\n\n";
print "DM_RPC_LIBS=\n\t$DM_RPC_LIBS\n\n";
print "OS_LIBS=\n\t$OS_LIBS\n\n";
    
# write makefile

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	'NAME'	=> 'Db::Documentum',
	'VERSION_FROM' => 'Documentum.pm',
	'LIBS'	=> ["$LD_LIBS $DM_CLIENT_LIBS $DM_RPC_LIBS $CPP_LIBS $OS_LIBS"],

# UNIX:
# You can also link against the shared client library if you want.  You'll need
# to have libC.so, libdmcl.so, and libc.so in your LD_LIBRARY_PATH.  This
# slows things down a little bit, but drastically decreases the size of the
# Documentum.so library.  Uncomment the LIBS expression below and comment out
# the one above if you want to use the shared libraries.
#    'LIBS'	=> ["-lC -ldmcl -lc"],

	'DEFINE'	=> '-DSQLNETV2 -DSYSV -D$OS -DOS_UNIX',
	'INC'	=> "$DM_INCLUDE $CPP_INCS",
	
	# This makes 'make ppd' happy
	($] ge '5.005')
	? (
	    'AUTHOR'   => 'Brian Spolarich (briansp@acm.org) and M. Scott Roth (michael.s.roth@saic.com)',
	    'ABSTRACT_FROM' => 'Documentum.pm',
	  )
	: (),    

	# This is just here to make 'make dist' easier to run.
	'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);

# __EOF__