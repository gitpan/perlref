# $Id: DistMakefile,v 1.5 1997-08-29 08:51:00+02 jv Exp $

################ Configuration ################

SHELL	= /bin/sh
PERL	= perl
PARR	= $(PERL) ./parr.pl

# Uncomment this if your printer has US letter format paper.
#PAPER	= -letter

# Uncomment this if your printer supports duplex printing.
#DUPLEX	= -duplex

# Uncomment this if your duplex printer prints the backside upside down.
#DUPLEX	= -duplex -notumble

# Alignment. See README for details.
HALIGN	= 0
VALIGN	= 0

################ End of Configuration ################

all :	refguide.ps

2pass :	guide-odd.ps guide-even1.ps guide-even2.ps

PFLAGS = $(PAPER) $(DUPLEX) -shift $(HALIGN) -topshift $(VALIGN)

# 2 pages per page, suitable for centrefold printing.
refguide.ps :	refbase.ps parr.pl
	$(PARR) $(PFLAGS) -bookorder \
		refbase.ps > refguide.ps

testpage.ps :	testbase.ps parr.pl Makefile
	$(PARR) $(PFLAGS) \
		testbase.ps > testpage.ps

# Odd and even passes for centerfold printing. 
# First print guide-odd.ps, then find out which of the others to use.
# guide-even1.ps is for printers with correct output stacking like
# Apple LaserWriter II. 
# guide-even2.ps for printers with reverse output stacking, like old
# Apple LaserWriters. 

guide-odd.ps :	refbase.ps parr.pl
	$(PARR) $(PFLAGS) \
		-bookorder -odd \
		refbase.ps > guide-odd.ps

guide-even1.ps :	refbase.ps parr.pl
	$(PARR) $(PFLAGS) \
		-bookorder -even \
		refbase.ps > guide-even1.ps

guide-even2.ps :	refbase.ps parr.pl
	$(PARR) $(PFLAGS) \
		-bookorder -even -reverse \
		refbase.ps > guide-even2.ps

guide-test.ps :	refbase.ps parr.pl
	$(PARR) $(PFLAGS) \
		refbase.ps > guide-test.ps

# System independent clean-up
clean :
	$(PERL) -e 'unlink(@ARGV)' refguide.ps guide-odd.ps guide-even1.ps \
		guide-even2.ps testpage.ps core *~

