#!/usr/local/bin/perl -w
my $RCS_Id = '$Id: parr.pl,v 5.14 1997-07-25 17:50:33+02 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Aug 15 1991
# Based On        : parr.pl by jgreely@cis.ohio-state.edu, 89/10/23
# Last Modified By: Johan Vromans
# Last Modified On: Fri Jul 25 17:13:35 1997
# Update Count    : 127
# Status          : OK

################ Common stuff ################

use strict;

# Package name.
my $my_package = "PerlRef";
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Command line parameters ################

use Getopt::Long;
my $verbose = 0;
my $opt_bookorder = 0;
my $opt_order = '';
my $opt_a4 = 0;
my $opt_letter = 0;
my $opt_odd = 0; 
my $opt_even = 0;
my $opt_reverse = 0;
my $opt_duplex = 0;
my $opt_notumble = 0;
my $opt_shift = 0;
my $opt_topshift = 0;
my $opt_gutter = 0;
my ($debug, $trace, $test) = (0, 0, 0);
app_options();
$trace |= $test || $debug;

################ Presets ################

################ The Process ################

# Find a temporary directory
my $TMPDIR = $ENV{TMPDIR};
$TMPDIR = "/usr/tmp" unless defined $TMPDIR and -d $TMPDIR;
unless ( defined $TMPDIR and -d $TMPDIR ) {
    $TMPDIR = $ENV{'sys$system'} eq "" ? "/usr/tmp" : 'SYS$SCRATCH:';
}
die ("No temporary directory found, please define TMPDIR\n")
  unless -d $TMPDIR and -w _;
$TMPDIR .= "/" unless $TMPDIR eq "" || $TMPDIR =~ /[:\]\/]$/;

# Read the input file, and split into parts.
# We gather some info in the fly.
my $file = "${TMPDIR}p$$.header";
my @files = ($file);
my $sheet = 0;
my $npages = 0;
my %pagemap;
my $twoup;
my @order = ();

open (FILE, ">$file") or die ("$file: $!\n");

while ( <> ) {
    # Hack to use NeXT Preview: strip old '%%Pages:' lines.
    if ( /^%%Pages:/ ) {
	$npages = $1 if $' =~ /\s*(\d+)/;
	print STDERR ("Number of pages = $npages.\n") if $verbose;
	next;
    }
    if ( /^%%Page:/ ) {
	$sheet++;
	$pagemap{$sheet} = $1 if /%%Page:\s+(\S+)\s+\S+/;
	close (FILE);
	$file = "${TMPDIR}p$$.$sheet";
	push (@files, $file);
	open (FILE, ">$file") or die ("$file: $!\n");
    }
    if ( /^%%Trailer/ ) {
	close (FILE);
	$file = "${TMPDIR}p$$.trailer";
	push (@files, $file);
	open(FILE, ">$file") or die ("$file: $!\n");
    }
    if ( /^%%EndSetup/ ) {
	# Insert twoup before switching to TeXDict.
	twoup();
	$twoup++;
	double_sided() if $opt_duplex;
	print FILE ("%%EndSetup\n");
	next;
    }
    if ( $opt_letter ) {
	# Special treatment for US letter freaks.
	if ( /^%%BoundingBox:\s*0 0 596 842/ ) {
	    $_ = "%%BoundingBox: 0 0 612 792\n";
	}
	if ( /^%%DocumentPaperSizes: A4/i ) {
	    $_ = "%%DocumentPaperSize: Letter\n";
	}
	if ( /^%%BeginPaperSize: A4/i ) {
	    scalar (<>);
	    $_ = "%%BeginPaperSize: Letter\nletter\n";
	}
	if ( /^%%PaperSize: A4/i ) {
	    $_ = "%%PaperSize: Letter\n";
	}
    }
    print FILE ($_);
}
close (FILE);
die ("twoup insertion error\n") unless $twoup == 1;

# Calculate order to output the pages.
if ( $opt_order ne '' ) {
    # Explicit range given.
    my $range;
    foreach $range ( split (/,/, $opt_order) ) {
	my ($start,$sep,$end) = split (/(-)/, $range);
	$start = 1 unless defined $start;
	$end = $sheet unless defined $end;
	if ( defined $sep ) {
	    push (@order, $start..$end);
	}
	else{
	    push (@order, $start);
	}
    }
}
elsif ( $opt_bookorder ) {
    # Normal book order: 8,1,2,7,6,3,4,5.
    # warn ("Warning: number of pages ($npages) is not a multiple of 4\n")
    #	unless $npages % 4 == 0;
    @order = bookorder(4*int($npages/4), $npages%4);
    if ( $opt_odd ) {
	# Select odd pages: 8,1,6,3.
	my @tmp = @order;
	@order = ();
	while ( @tmp > 0 ) {
	    push (@order, shift (@tmp), shift (@tmp));
	    shift (@tmp); shift (@tmp);
	}
    }
    elsif ( $opt_even ) {
	my @tmp = @order;
	@order = ();
	if ( $opt_reverse ) {
	    # Even pages: 2,7,4,5.
	    while ( @tmp > 0 ) {
		shift (@tmp); shift (@tmp);
		push (@order, shift (@tmp), shift (@tmp));
	    }
	}
	else {
	    # Even pages: 4,5,2,7.
	    while ( @tmp > 0 ) {
		shift (@tmp); shift (@tmp);
		unshift (@order, shift (@tmp), shift (@tmp));
	    }
	}
    }
}
else {
    # Pages in order. Make sure it's even.
    @order = (1..$sheet);
    push (@order, $sheet+1) if $sheet % 2;
}

# Mark pages out of order.
grep ((($_ > $sheet) && ($_ = '*')) || 1, @order);
print STDERR ("Page order = ", join(',',@order), "\n") if $verbose;

# Now glue the parts in the correct order together.
# The preamble info.
open (FILE, "${TMPDIR}p$$.header") or die("Error re-reading preamble\n");
$_ = <FILE>;
print STDOUT ($_, "%%Pages: ", int((@order+1)/2), " 0\n");
print STDOUT ($_) while <FILE>;
close (FILE);

# The pages.
my $count = 0;
my $page;
foreach $page (@order) {
    $count++;
    my $num = '*';
    $num = $pagemap{$page} if defined $pagemap{$page};
    if ( defined $order[$count] and defined $pagemap{$order[$count]} ) {
	$num .= '/' . $pagemap{$order[$count]};
    }
    else {
	$num .= '/*';
    }
    print STDOUT ("%%Page: $num ", ($count+1)/2, "\n") if $count & 1;
    print STDOUT ("%%OldPage: $page\n");
    if ($page eq "*") {
	print STDOUT ("0 0 bop eop\n");
    }
    else {
	if ( open (FILE, "${TMPDIR}p$$.$page") ) {
	    while ( <FILE> ) {
		print STDOUT ($_) unless /^%%Page:/;
	    }
	    close (FILE);
	}
	else {
	    warn ("Error re-reading page $page\n");
	}
    }
}

# The trailer info.
open (FILE, "${TMPDIR}p$$.trailer") or die ("Error re-reading trailer\n");
print STDOUT ($_) while <FILE>;
close (FILE);

# Wrapup and exit.
unlink @files unless $debug or $test;
exit(0);

################ Subroutines ################

sub bookorder {
    my ($pages, $offset) = @_;
    my (@order) = ();
    my $i;
    for ($i=1; $i<$pages/2; $i+=2) {
	push (@order, $pages-$i+1+$offset, $i+$offset, 
	      $i+1+$offset, $pages-$i+$offset);
    }
    @order;
}

sub twoup {
    my ($factor) = 0.707106781187;	# ridiculous (0.7 would do as well)
    my ($scale) = 72/75;
    my $topmargin;
    my $leftmargin;
    my $othermargin;
    $opt_shift *= $scale;
    $opt_topshift *= $scale;

    # Measurements are in 1/100 inch approx.
    # topmargin value shifts UP.
    # leftmargin value shifts RIGHT.

    if ( $opt_a4) {
	$topmargin = -5 - $opt_topshift;
	$leftmargin = 112 + $opt_shift;
	$othermargin = -445;	# do not change -- relative to $leftmargin
	$leftmargin -= $othermargin;
    }
    else {
	$topmargin = 10 - $opt_topshift;
	$leftmargin = 77 + $opt_shift;
	$othermargin = -445;	# do not change -- relative to $leftmargin
	$leftmargin -= $othermargin;
    }

    # Add any extra gutter margins

    $leftmargin += $opt_gutter;
    $othermargin -= ($opt_gutter * 2);

    print FILE <<EOD;
/isls true def
userdict begin 
/isoddpage true def
/orig-showpage /showpage load def
/showpage {
        isoddpage not { orig-showpage } if
        /isoddpage isoddpage not store 
    } def
 
/bop-hook {
        isoddpage 
	{ $factor $factor scale $topmargin $leftmargin translate }
        { 0 $othermargin translate}
	ifelse
    } def
 
/end-hook{ isoddpage not { orig-showpage } if } def
end
EOD
}

sub double_sided {

    # From: Tim Huckvale <tjh@praxis.co.uk>
    #
    # You may be interested in the following problem, and fix, that we
    # found when attempting to print the reference card on our Hewlett
    # Packard Laser-Jet IIISi printer.
    # 
    # On this printer, refguide.ps prints double-sided with the
    # reverse side of each sheet upside down.  We fixed it with the
    # following patch, applied before printing.

    # From: Johan Vromans <jvromans@squirrel.nl>
    #
    # Okay -- consider this an unsupported feature.

    # From: Hoylen Sue <hoylen@dstc.edu.au>
    #
    # ... Thus, I always find myself wanting to print it out
    # with a larger gutter margin (i.e. the pages A5 centered rather than
    # being very close to the fold).
    # To this end, I have added a gutter argument which shifts the margins
    # around. The new `twoup' subroutine in parr.pl is:

    # From: Johan Vromans <jvromans@squirrel.nl>
    #
    # Okay -- consider this an unsupported feature.

    print FILE ("statusdict /setduplexmode known { ",
                "statusdict begin true setduplexmode end } if\n",
		"statusdict /settumble known { ",
                "statusdict begin ",
                $opt_notumble ? "false" : "true",
		" settumble end } if\n");
}

sub app_ident();
sub app_usage($);

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    # Preset defaults.
    $opt_bookorder = $opt_even = $opt_odd = $opt_reverse = 0;
    $opt_a4 = $opt_letter = 0;
    $opt_order = '';
    $opt_shift = $opt_topshift = 0;

    return unless @ARGV > 0;
    
    if ( !GetOptions(
		     'bookorder' => \$opt_bookorder,
		     'order=s'	=> \$opt_order,
		     'a4'	=> \$opt_a4,
		     'letter'	=> \$opt_letter,
		     'odd'	=> \$opt_odd, 
		     'even'	=> \$opt_even,
		     'reverse'	=> \$opt_reverse,
		     'duplex'	=> \$opt_duplex,
		     'notumble'	=> \$opt_notumble,
		     'shift=i'	=> \$opt_shift,
		     'topshift=i' => \$opt_topshift,
		     'gutter=i'	=> \$opt_gutter,
		     'ident'	=> \$ident,
		     'verbose'	=> \$verbose,
		     'trace'	=> \$trace,
		     'help'	=> \$help,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
    app_ident() if $ident;
}

sub app_ident () {
    print STDERR ("This is $my_package [$my_name $my_version]\n");
}

sub app_usage ($) {
    my ($exit) = @_;
    app_ident();
    print STDERR <<EndOfUsage;
Usage: $0 [options] [file ...]
    -a4		 map for A4 size paper
    -letter	 map for US Letter size paper
    -bookorder	 output pages in book order
    -odd	 odd pages only (use with -bookorder)
    -even	 even pages only (use with -bookorder)
    -shift NN	 shift right by NN units (1/100 inch approx.)
    -topshift NN shift down by NN units (1/100 inch approx.)
    -gutter NN   add extra gutter margin of NN units (1/100 inch approx.)
    -reverse	 reversed order (use with -bookorder -even)
    -duplex	 try duplex printing
    -notumble	 avoid backside tumbling (with -duplex)
    -order n,n,... explicit page order
    -help	 this message
    -ident	 show identification
    -verbose	 verbose information
EndOfUsage
    exit $exit if $exit != 0;
}
