# $Id: Makefile,v 5.8 1995/12/24 15:17:40 jv Exp $

################ Configuration ################

SHELL	= /bin/sh
PERL	= perl
LATEX	= latex
DVIPS	= dvips

# Uncomment this if your printer has US letter format paper.
#PAPER	= -letter

# Uncomment this if your printer supports duplex printing.
#DUPLEX	= -duplex

# Alignment. See README for details.
HALIGN	= 0
VALIGN	= 0

################ End of Configuration ################

all:	refguide.ps refcover.ps

2pass:	guide-odd.ps guide-even1.ps guide-even2.ps refcover.ps

# 2 pages per page, suitable for centrefold printing.
refguide.ps:	refbase.ps parr.pl
	$(PERL) ./parr.pl $(PAPER) $(DUPLEX) -bookorder \
		-shift $(HALIGN) -topshift $(VALIGN) \
		refbase.ps > refguide.ps

refcover.ps:	refcbase.ps parr.pl
	$(PERL) ./parr.pl $(PAPER) $(DUPLEX) -order 2,1 \
		-shift $(HALIGN) -topshift $(VALIGN) \
		refcbase.ps > refcover.ps

testpage.ps:	testbase.ps parr.pl Makefile
	$(PERL) ./parr.pl $(PAPER) $(DUPLEX) \
		-shift $(HALIGN) -topshift $(VALIGN) \
		testbase.ps > testpage.ps

# Odd and even passes for centerfold printing. 
# First print guide-odd.ps, then find out which of the others to use.
# guide-even1.ps is for printers with correct output stacking like
# Apple LaserWriter II. 
# guide-even2.ps for printers with reverse output stacking, like old
# Apple LaserWriters. 

guide-odd.ps:	refbase.ps parr.pl
	$(PERL) ./parr.pl $(PAPER) -bookorder -odd \
		refbase.ps > guide-odd.ps

guide-even1.ps:	refbase.ps parr.pl
	$(PERL) ./parr.pl $(PAPER) -bookorder -even \
		refbase.ps > guide-even1.ps

guide-even2.ps:	refbase.ps parr.pl
	$(PERL) ./parr.pl $(PAPER) -bookorder -even -reverse \
		refbase.ps > guide-even2.ps

guide-test.ps:	refbase.ps parr.pl
	$(PERL) ./parr.pl $(PAPER) refbase.ps > guide-test.ps

clean:
	rm -f refguide.ps guide-odd.ps guide-even1.ps guide-even2.ps \
		refcover.ps refbase.dvi core *~

# The remainder of this Makefile is for maintenance use only.

VER	= 5.001

CH	= ch-*.tex
SRC	= refbase.tex refbase.cls testbase.ps # refbase.toc 
AUX	= README ChangeLog Makefile Makefile.psutils parr.pl PROBLEMS Layout

# NOTE: DO NOT REMOVE OR CHANGE '-ta4' EVEN IF USING NON-A4 PAPER
refbase-ps:	refbase.dvi
	$(DVIPS) -r0 -ta4 refbase.dvi -o refbase.ps

refbase.dvi:	$(SRC)
	touch refbase.toc
	@rm -f refbace.toc~
	@cat refbase.toc > refbase.toc~
	$(LATEX) refbase.tex < /dev/null
	@if cmp refbase.toc refbase.toc~ > /dev/null 2>&1; \
	then \
	    true; \
	else \
	    echo "$(LATEX) refbase.tex \< /dev/null"; \
	    $(LATEX) refbase.tex < /dev/null; \
	fi

MASTER  = ref
refbase-tex:  $(MASTER)master.tex $(CH) makebase.pl
	$(PERL) ./makebase.pl $(REV) refcmaster.tex > refcbase.tex
	$(PERL) ./makebase.pl $(REV) $(MASTER)master.tex > refbase.tex

refcbase-ps:	refcbase.tex refbase.cls
	$(LATEX) refcbase.tex < /dev/null
	$(DVIPS) -r0 -ta4 refcbase.dvi -o refcbase.ps

kit:	
	REV=`cat Revision.SEQ`; \
	expr $$REV + 1 >Revision.SEQ; \
	$(MAKE) -$(MAKEFLAGS) REV=$$REV \
		refbase-tex refbase-ps refcbase-ps kitinternal

kitinternal:
	rm -f perlref-*.shr.* perlref-$(VER).$(REV).tar.gz
	gtar -zcvf perlref-$(VER).$(REV).tar.gz \
		$(AUX) $(SRC) refbase.ps refcbase.ps

xkitinternal:
	rm -f perlref-*.shr.* perlref-$(VER).$(REV).tar.gz
	shar -c -n perlref-$(VER).$(REV) -a -s 'jvromans@squirrel.nl' \
		-o perlref-$(VER).$(REV).shr -L50 -f \
		$(AUX) $(SRC) refbase.ps refcbase.ps
	gtar -zcvf perlref-$(VER).$(REV).tar.gz \
		$(AUX) $(SRC) refbase.ps refcbase.ps
	ls -l perlref-*.shr.* perlref-*.tar.gz
