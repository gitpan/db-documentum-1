package Db::Documentum;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $AUTOLOAD);

use Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
$VERSION = '1.4';

@EXPORT_OK = qw(
	dmAPIInit
	dmAPIDeInit
	dmAPIGet
	dmAPISet
	dmAPIExec
	ALL
	all
);

%EXPORT_TAGS = (
	ALL => [qw( dmAPIInit dmAPIDeInit dmAPIGet dmAPISet dmAPIExec )],
	all => [qw( dmAPIInit dmAPIDeInit dmAPIGet dmAPISet dmAPIExec )]
);

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
	 if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	 }
	 else {
	    croak "Your vendor has not defined Db::Documentum macro $constname";
	 }
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Db::Documentum $VERSION;

## -----------------
## Automatic API initialization code
die "\nERROR: Db::Documentum could not properly initialize the Documentum API interface.\n\n"
      unless dmAPIInit();

## Automatic API de-initialization code
END
{  warn "\nWARNING: Db::Documentum could not properly de-initialize the Documentum API interface.\n\n"
      unless dmAPIDeInit();
}
## -----------------

1;

__END__

=head1 NAME

Db::Documentum - Perl extension for Documentum Client Libraries.

=head1 SYNOPSIS

	use Db::Documentum;
	use Db::Documentum qw(:all);

	string = dmAPIGet(<method>);
	$sessionID = dmAPIGet("connect,docbase,username,password");

	scalar = dmAPIExec(<method>);
	$obj_id = dmAPIExec("create,c,dm_document");

	scalar = dmAPISet(<method>,<value>);
	$api_stat = dmAPISet("set,c,last,object_name","My Document");


=head1 DESCRIPTION

The B<Db::Documentum> module provides a Perl interface to
the client API libraries for the Documentum Enterprise Document
Management System (EDMS98 and 4i). You must have already
obtained the necessary libraries and purchased the necessary
licenses from Documentum before you can build this module. For
more information on Documentum EDMS, see
I<http://www.documentum.com/>

This module provides an interface to the three listed API
functions: B<dmAPIGet>, B<dmAPIExec>, and B<dmAPISet>. For most purposes,
these are the only functions you need to use, as the bulk of the 
API is implemented as server methods accessed by one of the API 
commands. B<dmAPIExec> returns a scalar (1 or 0) which can be evaluated 
to determine success (1 for success, 0 for failure). B<dmAPISet> also 
returns a scalar, but takes two arguments, the method argument and the 
value to use. B<dmAPIGet> takes a single argument and returns a string 
containing the results. This string, which may contain an object or 
query collection identifier can be used later with other method calls.
    
This module, by default, does not import all of its symbols into the calling
package's namespace.  Therefore, the Documentum API commands must be
called with the fully-qualified package path:

	Db::Documentum::dmAPIGet

To use the module functions without having to supply the module name,
use the second form of the "use" statement shown above:

	use Db::Documentum qw (:all);

That said, check your Documentum documentation for complete information
on how to interact with the Documentum server.

=head1 WARRANTY

There is none, implied, expressed, or otherwise.  We are providing this gratis,
out of the goodness of our hearts.  If it breaks, you get what you
paid for.

=head1 LICENSE

The Documentum perl extension may be redistributed under the same terms as
Perl.  The Documentum EDMS is a commercial product.  The product name,
concepts, and even the mere thought of the product are the sole property of
Documentum, Inc. and its shareholders.

=head1 AUTHORS

Brian W. Spolarich, ANS/UUNET WorldCom, C<briansp@ans.net>
M. Scott Roth, Science Applications International Corporation,
C<Scott_Roth@saic-nmsd.com>

=head1 SEE ALSO

perl(1).

=cut
