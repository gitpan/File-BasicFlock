# Copyright (C) 1996, David Muir Sharnoff

package File::BasicFlock;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(lock unlock);

use Carp;

#
# It would be nice if I could use fcntl.ph and
# errno.ph, but alas, that isn't safe.
#
use POSIX qw(EAGAIN ENOENT EEXIST O_EXCL O_CREAT O_RDONLY O_WRONLY); 
sub LOCK_SH {1;}
sub LOCK_EX {2;}
sub LOCK_NB {4;}
sub LOCK_UN {8;}

use vars qw($VERSION %locks %lockHandle %shared $debug);

BEGIN	{
	$VERSION = 96.042302;
	$debug = 0;
}

use strict;
no strict qw(refs);

my $gensym = "sym0000";

sub lock
{
	my ($file, $shared, $nonblocking) = @_;
	#my $f = new FileHandle;

	$gensym++;
	my $f = "File::Flock::$gensym";

	my $previous = exists $locks{$file};

	# the file may be springing in and out of existance...
	unless (sysopen($f, $file, O_RDONLY)) {
		croak "open $file: $!";
	}
	$locks{$file} = $locks{$file} || 0;
	$shared{$file} = $shared;
	
	$lockHandle{$file} = $f;

	my $flags;

	$flags = $shared ? &LOCK_SH : &LOCK_EX;
	$flags |= &LOCK_NB
		if $nonblocking;
	
	my $r = flock($f, $flags);

	print " ($$ " if $debug and $r;

	return 1 if $r;
	if ($nonblocking and $! == EAGAIN) {
		if (! $previous) {
			delete $locks{$file};
			my $f = $lockHandle{$file};
			close($f);
			delete $lockHandle{$file};
			delete $shared{$file};
		}
		return 0;
	}
	croak "flock $f $flags: $!";
}

sub unlock
{
	my ($file) = @_;

	croak "no lock on $file" unless exists $locks{$file};

	delete $locks{$file};
	my $f = $lockHandle{$file};
	delete $lockHandle{$file};

	return 0 unless defined $f;

	print " $$) " if $debug;
	flock($f, &LOCK_UN)
		or croak "flock $f UN: $!";

	close($f);
	return 1;
}

END {
	my $f;
	for $f (keys %locks) {
		&unlock($f);
	}
}

__DATA__

=head1 NAME

 File::BasicFlock - file locking with flock

=head1 SYNOPSIS

 use File::BasicFlock;

 lock($filename);

 lock($filename, 'shared');

 lock($filename, undef, 'nonblocking');

 lock($filename, 'shared', 'nonblocking');

 unlock($filename);

=head1 DESCRIPTION

Lock files using the flock() call.  The file to be locked must 
already exist.

=head1 AUTHOR

David Muir Sharnoff, <muir@idiom.com>


