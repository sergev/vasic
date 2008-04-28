#bin_PROGRAMS = vasic
#vasic_SOURCES =
AM_CFLAGS = -Wall -g -O
SUFFIXES	= .d

all-local:	scanner_test parser_test

clean-local:
		rm -rf *~ *.o *.out parser.d *_test

scanner_test:	scanner.d
		gdc $(CFLAGS) -fdebug=scanner -o $@ scanner.d
		rm -f scanner.o

parser_test:	parser.d scanner.o node.o
		gdc $(CFLAGS) -fdebug=parser -fdebug=lemon -o $@ parser.d  scanner.o node.o
		rm -f parser.o

parser.d:	parser.lemon
		lemon -ld -q $<


.d.o:
		gdc $(CFLAGS) -c $<

#node.o: 	parser.d
#scanner.o: 	scanner.d parser.d node.d
