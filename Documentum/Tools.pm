package Db::Documentum::Tools;

use Carp;
use Exporter;
use Socket;
use Sys::Hostname;
use Db::Documentum qw(:all);
require 5.004;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = '1.4';
$error = "";

@EXPORT_OK = qw(
	dm_Connect
	dm_KrbConnect
	dm_LastError
	dm_LocateServer
	dm_Locate_Child
	dm_CreateType
	dm_CreateObject
	dm_CreatePath
	all
	ALL
);

%EXPORT_TAGS = (
	ALL => [qw( dm_Connect dm_KrbConnect dm_LastError dm_LocateServer
				dm_Locate_Child dm_CreateType dm_CreateObject dm_CreatePath)],
	all => [qw( dm_Connect dm_KrbConnect dm_LastError dm_LocateServer
				dm_Locate_Child dm_CreateType dm_CreateObject dm_CreatePath)]
);

### Default string delimiter used by dm_CreateObject
$Delimiter = '::';
###

# Connects to the given docbase with the given parameters, and
# returns a session identifer.
sub dm_Connect($$$;$$) {
   my $docbase = shift;
   my $username = shift;
   my $password = shift;
   undef my $session;

   unless ($OS) {
      unless ($OS = $^O) {
	      require Config;
	      $OS = $Config::Config{'osname'};
      }
   }

   if ($OS =~ /Win/i) {
      $session = dmAPIGet("connect,$docbase,$username,$password");
   } else {
	   my $user_arg_1 = shift;
	   my $user_arg_2 = shift;
	   $session = dmAPIGet("connect,$docbase,$username,$password,$user_arg_1,$user_arg_2");
	}
	return $session;
}

# Returns documentum error information.
sub dm_LastError (;$$$) {
	my($session,$level,$number) = @_;
	my($return_data);
	$session = 'apisession' unless ($session);
	$level = '3' unless ($level);	# Set a default level to report.
	$number = 'all' unless ($number);
	my($message_text) = dmAPIGet("getmessage,$session,$level");
	if ($number eq "all") {
		$return_data = $message_text;
	} else {
		my(@message_list) = split('\n',$message_text);
		for ($i = 0 ; $i < $number ; $i++) {
			$return_data .= sprintf("%s\n",$message_list[$i]);
		}
	}
	$return_data;
}

#
# dm_KrbConnect - Obtains a documentum client session using a K4 session
# 		  ticket.  Requires a compatible dm_check_password utility
#                 on the server side.
sub dm_KrbConnect ($;$) {
	my($docbase,$username) = @_;
	my($service) = 'documentum';
	my($time) = time();
	my($nonce_prefix) = "KERBEROS_V4_NONCE__";
	my($nonce_data) = "${nonce_prefix}${time}";

	# Find the documentum server we're going to be connecting to from
	# whatever docbroker we're going to find.
	my($server_hostname) = dm_LocateServer($docbase);
	if (! $server_hostname) {
		# dm_LocateServer sets Documentum::Tools::error for us.
		return;
	}

	# We need the address as a four byte packed string for krb_mk_priv.
	my($server_inaddr) = inet_aton($server_hostname);
	if(! $server_inaddr) {
		${'error'} = "Unable to obtain server address.\n";
	}

	my($client_hostname) = hostname();

	if (! $client_hostname) {
		${'error'} = "Unable to obtain local hostname.";
		return;
	}

	# We need the address as a four byte packed string for krb_mk_priv.
	my($client_inaddr) = inet_aton($client_hostname);
	if(! $client_inaddr) {
		${'error'} = "Unable to obtain local address.\n";
	}

	my($realm) = Krb4::realmofhost($server_hostname);
	if (! $realm) {
		${'error'} = "Unable to determine realm of host $server_hostname: ";
		${'error'} .= Krb4::get_err_txt($Krb4::error);
		${'error'} .= " [$Krb4::error]\n";
		return;
	}
	my($phost) = Krb4::get_phost($server_hostname,$realm,$service);
	if (! $phost) {
		${'error'} = "Unable to determine instance for host $server_hostname in realm $realm: ";
		${'error'} .= Krb4::get_err_txt($Krb4::error);
		${'error'} .= " [$Krb4::error]\n";
		return;
	}
	my($ticket) = Krb4::mk_req($service,$phost,$realm,200);
	if (! $ticket) {
		${'error'} = "Unable to obtain a ticket: ";
		${'error'} .= Krb4::get_err_txt($Krb4::error);
		${'error'} .= " [$Krb4::error]\n";
		return;
	}
	my($ticket_data) = $ticket->dat;

	my($creds) = Krb4::get_cred($service,$phost,$realm);
	if (! $creds) {
		${'error'} = "Unable to obtain credential data: ";
		${'error'} .= Krb4::get_err_txt($Krb4::error);
		${'error'} .= " [$Krb4::error]\n";
		return;
	}
	# If the caller didn't specify a username to log in as, then
	# use the one in their ticket (i.e. theirs).
	if (! $username) {
		$username = $creds->pname;
	}
	my($session_key) = $creds->session;
	my($key_schedule) = Krb4::get_key_sched($session_key);

	if (! $key_schedule) {
		${'error'} = "Unable to obtain encryption key schedule: ";
		${'error'} .= Krb4::get_err_txt($Krb4::error);
		${'error'} .= " [$Krb4::error]\n";
		return;
	}

	# Construct a nonce for this session.  Here we will use the time
	# encrypted with the session key.
	my($nonce) = Krb4::mk_priv($nonce_data,$key_schedule,$session_key,
									$client_inaddr,$server_inaddr);

#	print STDERR "session_key: $session_key\n";
#	print STDERR "time: $time\n";
#	print STDERR "key_schedule: $key_schedule\n";
#	print STDERR "client_inaddr: $client_inaddr\n";
#	print STDERR "client_addr:", inet_aton($client_inaddr), "\n";
#	print STDERR "server_inaddr: $server_inaddr\n";
#	print STDERR "server_addr:", inet_aton($server_inaddr), "\n";
#	print STDERR "nonce_data: $nonce_data\n";
#	print STDERR "nonce: $nonce\n";

	if (! $nonce) {
		${'error'} = "Unable to obtain encrypt nonce: ";
		${'error'} .= Krb4::get_err_txt($Krb4::error);
		${'error'} .= " [$Krb4::error]\n";
		return;
	}
#	print STDERR Krb4::get_err_txt($Krb4::error), "\n";

	# uuencode ticket data, then encode it with URI-style encoding
	my($ticket_data_encoded) = pack "u", $ticket_data;
	$ticket_data_encoded =~ s/([^A-Za-z0-9])/uc sprintf("%%%02x",ord($1))/eg;

	# Same thing for nonce.
	my($nonce_encoded) = pack "u", $nonce;
	$nonce_encoded =~ s/([^A-Za-z0-9])/uc sprintf("%%%02x",ord($1))/eg;

#	print "nonce_encoded: $nonce_encoded\n";

	# Okay.  Now we've got an encoded service ticket for this session.
	# Send it as our password to the documentum server for
	# validation.  We include the nonce as both additional
	# params, because connect doesn't seem the pass the first one properly.
	my($session_id) = dmAPIGet("connect,$docbase,$username,$ticket_data_encoded,,$nonce_encoded");
	if (! $session_id) {
		${'error'} = "Unable to obtain a docbase session id:\n";
		${'error'} .= dm_LastError();
		return;
	} else {
		return $session_id;
	}
}

# Find the active server for a given docbase.
#
#   $server = dm_LocateServer($docbase);
#
sub dm_LocateServer ($) {
	my $docbase = shift;
	my $locator = dmAPIGet("getservermap,apisession,$docbase");
    my $hostname = dmAPIGet("get,apisession,$locator,i_host_name")
        if ($locator);

    return ($hostname) ? $hostname : undef;
}

# Returns the object id (if any) of the object to which this object is
# a parent based on the relation type.
sub dm_Locate_Child ($$$) {
	my($ss,$object_id,$relation_type) = @_;

	my($relation_obj_id) = dmAPIGet("id,$ss,dm_relation where parent_id = '$object_id' and relation_name = '$relation_type'");
	if (! $relation_obj_id) { return 0 ; }
	my($child_object_id) = dmAPIGet("get,$ss,$relation_obj_id,child_id");
	if (! $child_object_id) { return -1; } # This is most likely an error.
	$child_object_id;
}

# Create a Documentum object and populate attributes.
#
#     %ATTRS = (object_name =>  'test_doc2',
#               title       =>  'My Test Doc 2',
#               authors     =>  'Scott 1::Scott 2',
#               keywords    =>  'Scott::Test::Doc::2',
#               r_version_label => 'TEST');
#
#     $doc_id = dm_CreateObject ("dm_document",%ATTRS);
#
sub dm_CreateObject($;%) {

   my $dm_type = shift;
   my %attrs = @_;
   my $api_stat = 1;

   my $obj_id = dmAPIGet("create,c,$dm_type");

   if ($obj_id) {
      foreach my $attr (keys %attrs) {
         if(dmAPIGet("repeating,c,$obj_id,$attr")) {
            my @r_attr = split($Db::Documentum::Tools::Delimiter,$attrs{$attr});
            foreach (@r_attr) {
                $api_stat = 0 unless dmAPISet("append,c,$obj_id,$attr",$_);
            }
         }
         else {
            $api_stat = 0 unless dmAPISet("set,c,$obj_id,$attr",$attrs{$attr});
         }
      }
   }
   else { $api_stat = 0; }

   return (! $obj_id || ! $api_stat) ? undef : $obj_id;
}

# Create a new Documentum object type.
#
#     %field_defs = (cat_id    => 'char(16)',
#                    loc       => 'char(64)',
#                    editions  => 'char(6) REPEATING');
#     dm_CreateType ("my_document","dm_document",%field_defs);
#
sub dm_CreateType($$;%) {

   my $name = shift;
   my $super_type = shift;
   my %field_defs = @_;
   my $sql_body = "";

   if (keys %field_defs) {
      foreach my $field (keys %field_defs) {
         $sql_body .= "$field $field_defs{$field},";
      }
      $sql_body =~ s/\,$//;
      $sql_body = "($sql_body)";
   }

   my $sql = "CREATE TYPE $name $sql_body WITH SUPERTYPE $super_type";
   my $api_stat =  dmAPIExec("execquery,c,,$sql");

   if ($api_stat) {
      my $col_id = dmAPIGet("getlastcoll,c,");
      dmAPIExec("close,c,$col_id") if $col_id;
   }

   return $api_stat;
}

# Create a new folder in the Docbase.
#
#     dm_CreatePath ('/Temp/Test/Unit-1');
#
sub dm_CreatePath($) {
    my $path = shift;
    
    # Break path into heirarchical elements
    my @dirs = split("/",$path);

    my $dm_path = "";

    # if it already exists, just return
    my $dir_id = dmAPIGet("id,c,dm_folder where any r_folder_path = \'$path\'");
    return $dir_id if $dir_id;

    # Test each heirarchical path for existance
    foreach my $dir (@dirs) {
        if ($dir =~ /^\w/) {
            $dm_path .= "/$dir";

            # Does this partial path exist?
            $dir_id = dmAPIGet("id,c,dm_folder where any r_folder_path = \'$dm_path\'");
            
            # If not, create it
            if (! $dir_id) {
                my %dir_attrs = ();
                $dir_attrs{'object_name'} = $dir;

                # Create the cabinet if needed                
                if ($dm_path =~ /^\/[\w\d]+$/) {
                    $dir_id = dm_CreateObject("dm_cabinet",%dir_attrs);
                    return undef unless dmAPIExec("save,c,$dir_id");  
                # Create a folder                      
                } else {    
                    $dir_id = dm_CreateObject("dm_folder",%dir_attrs);
                    return undef unless $dir_id;

                    # Link it to its parent
                    my $folder_path = $dm_path;
                    $folder_path =~ s/\/$dir$//;
                    if ($folder_path =~ /\w+/) {
                        return undef 
                            unless dmAPIExec("link,c,$dir_id,\'$folder_path\'");
                        return undef 
                            unless dmAPIExec("save,c,$dir_id");
                    }        
                }
            }
        }
    }
    return $dir_id;
}
1;
__END__

=head1 NAME

Db::Documentum::Tools - Support functions for Db::Documentum.

=head1 SYNOPSIS

	use Db::Documentum::Tools;
	use Db::Documentum::Tools qw(:all);

	$session_id = dm_Connect($docbase,$user,$password);
	$session_id = dm_Connect($docbase,$user,$password,
	                         $user_arg_1,$user_arg_2);

	$error_msg = dm_LastError();
	$error_msg = dm_LastError($session_id);
	$error_msg = dm_LastError($session_id,1);
	$error_msg = dm_LastError($session_id,$level,$number);
	
    $object_id = dm_CreateObject("dm_document",%ATTRS);
    $object_id = dm_CreateObject("dm_document");

    $api_stat = dm_CreateType("my_document","dm_document",%field_defs);
    $api_stat = dm_CreateType("my_document","dm_document");
    
    $obj_id = dm_CreatePath('/Temp/Test/Unit-1');

	$session_id = dm_KrbConnect($docbase);

	$hostname = dm_LocateServer($docbase);

=head1 DESCRIPTION

Db::Documentum::Tools is a collection of frequently used Documentum procedures
encapsulated by Perl.

=head1 LICENSE

The Documentum perl extension may be redistributed under the same terms as Perl.
The Documentum EDMS is a commercial product.  The product name, concepts,
and even the mere thought of the product are the sole property of
Documentum, Inc. and its shareholders.

=head1 AUTHOR

Brian W. Spolarich, ANS/UUNET WorldCom, C<briansp@ans.net>
M. Scott Roth, Science Applications International Corporation,
C<Scott_Roth@saic-nmsd.com>

=head1 SEE ALSO

Db::Documentum.

=cut
