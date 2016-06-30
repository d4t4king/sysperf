#!/usr/bin/perl

package LASObjects::SMARTDisk;

use strict;
use warnings;

use feature qw( switch );
use 5.010_001;
no if $] ge '5.018', warnings => "experimental::smartmatch";

use Term::ANSIColor;
use Data::Dumper;

use lib '/root/local-admin-scripts';
use LASObjects;

{
	$LASObjects::SMARTDisk::VERSION = '0.1';
}

our %from_bool  = ( 'true'=>1, 'false'=>0 );
our %to_bool    = ( 1=>'true', 0=>'false' );

chomp( our $smartctl = LASObjects->get_binary('smartctl') );

sub new {
	my ($class,@devices) = @_;
	my $self = bless {}, $class;

	if (!@devices) {
		# try to "glean" the info from the mount command
		my $mount = LASObjects->get_binary('mount');
		my @mounts = qx($mount);
		#print Dumper(\@mounts);

		foreach my $m ( @mounts ) {
			chomp($m);
			$m = &trim($m);
			next if ($m =~ /^(?:te?mpfs|udev|proc|sysfs|cgroup|devpts|securityfs|pstore|debugfs|systemd|fusectl|hugetlbfs|rpc\_pipefs|vmware|mqueue|binfmt_misc|\/\/)/);
			next if ($m =~ /^\/dev\/mapper\/.*\-root/);
			#print colored("$m \n", "bold cyan");
			my $d = (split(/\s+/, $m))[0];
			#print colored("$d \n", "cyan");
			push @devices, $d;
		}
	}

	$self->update_data($_) foreach @devices;

	return $self;
}

sub update_data {
	my $self	= shift(@_);
	my $device	= shift(@_);

	my $out = qx($smartctl -a $device) if ((defined($smartctl)) and ($smartctl ne ''));
	chomp($out);
	print colored("$device \n", "bold blue");

	foreach my $line ( split(/\n+/, $out) ) {
		given ($line) {
			when (/\=\=\=\s+START\s+OF\s+READ\s+SMART\s+DATA\s+SECTION\s+\=\=\=/) { last; }
			when (/Device\s+Model\:\s+(.*)/)					{ $self->{'devices'}->{$device}->{'info'}{'model'} = $1; }
			when (/Serial\s+Number\:\s+(.*)/)					{ $self->{'devices'}->{$device}->{'info'}{'serial_number'} = $1; }
			when (/Firmware\s+Version\:\s+(.*)/)				{ $self->{'devices'}->{$device}->{'info'}{'firmware_ver'} = $1; }
			when (/LU\s+WWN\s+Device\s+Id\:\s+(.*)/)			{ $self->{'devices'}->{$device}->{'info'}{'lu_wnn_device_id'} = $1; }
			when (/Form\s+Factor\:\s+(.*)/)						{ $self->{'devices'}->{$device}->{'info'}{'form_factor'} = $1; }
			when (/User\s+Capacity\:\s+([0-9,]+)\s+bytes\s+\[(.*)\]/) {
				$self->{'devices'}->{$device}->{'info'}{'capacity_bytes'} = $1;
				$self->{'devices'}->{$device}->{'info'}{'capacity_hr'} = $2;
			}
			when (/Sector\s+Size\:\s+(.*)/)						{ $self->{'devices'}->{$device}->{'info'}{'sector_size'} = $1; }
			when (/Rotation\s+Rate\:\s+(.*)/)					{ $self->{'devices'}->{$device}->{'info'}{'rotation_rate'} = $1; }
			when (/Device\s+is\:\s+(.*)/)						{ 
				my $d = $1;
				#print colored("D: $d \n", "bold cyan");
				if ($d =~ /^Not\s+in\s+smartctl\s+database.*/) { 
					$self->{'devices'}->{$device}->{'info'}{'in_database'} = $from_bool{'false'}; }
				else { $self->{'devices'}->{$device}->{'info'}{'in_database'} = $from_bool{'true'}; }
			}
			when (/ATA\s+Version\s+is\:\s+(.*)/)				{ $self->{'devices'}->{$device}->{'info'}{'ata_ver'} = $1; }
			when (/SATA\s+Version\s+is\:\s+(.*)/)				{ $self->{'devices'}->{$device}->{'info'}{'sata_ver'} = $1; }
			when (/SMART\s+support\s+is\:\s+(.*)/)				{ 
				my $d = $1; 
				print colored("D: $d \n", "bold cyan");
				given ($d) {
					when (/^Available\s+\-\s+.*/)	{ 
						$self->{'devices'}->{$device}->{'info'}{'smart_available'} = $from_bool{'true'}; }
				#else { $self->{'devices'}->{$device}->{'info'}{'smart_available'} = $from_bool{'false'}; }
					when (/^Enabled.*/) 			{ 
						$self->{'devices'}->{$device}->{'info'}{'smart_enabled'} = $from_bool{'true'}; }
				#else { $self->{'devices'}->{$device}->{'info'}{'smart_enabled'} = $from_bool{'false'}; }
					default { next; }
				}
			}
			when (/smartctl\s+\d\.\d* \d+\-\d+\-\d+\s+r\d+/)	{ next; }
			when (/Local\s+Time\s+is\:/)						{ next; }
			when (/\=\=\=\s+START.*/)							{ next; }
			when (/Copyright \(C\).*/)							{ next; }
			default { die colored("Line didn't match: $line \n", "bold red"); }
		}
	}

	return $from_bool{'true'};
}

sub	ltrim { my $s = shift(@_); $s =~ s/^\s+//;       return $s; }
sub	rtrim { my $s = shift(@_); $s =~ s/\s+$//;       return $s; }
sub	 trim { my $s = shift(@_); $s =~ s/^\s+|\s+$//g; return $s; }

1;
