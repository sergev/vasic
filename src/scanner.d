module scanner;

import std.stdio;
import std.stream;
import std.string;
import std.uni;
import std.utf;
private import std.c.stdlib;

enum {
	LEX_NUMBER = 256,
	LEX_NAME,
	LEX_STRING,
	LEX_LABEL,
	LEX_LE,
	LEX_GE,
	LEX_NEQ,
}

/*
 * Lexeme read from input file.
 */
class lexeme_t {
	int type;	/* Lexeme type */
	int line;	/* Source line number */
	int column;	/* Source column position */
	string source;	/* As read from source file */
	double number;	/* Value for number constants */
	string text;	/* Value for identifiers, labels and string literals */

	this (int t, string src) {
		type = t;
		line = 0;
		column = 0;
		source = src;
	}

	void print (int offset)
	{
		for (int i=0; i<offset; ++i)
			printf ("    ");
		if (offset < 0)
			offset = -offset;
		if (! this) {
			writefln ("(null)");
			return;
		}
		if (source.length > 0)
			writef ("%s ", source);
		else if (type == LEX_STRING)
			writef ("\"%s\" ", text);
		writef ("(%d)", type);
		if (line)
			writef (" (%d:%d)", line, column);
		writefln ("");
	}
}

/*
 * Lexical scanner.
 */
class scanner_t {
	lexeme_t token;
	string filename;
	int line;
	int column;
	int tab_width;
	private lexeme_t next;
	private wchar backchar;
	private BufferedFile file;

	/*
	 * Open a file for parsing.
	 */
	this (string name) {
		file = new BufferedFile (name);
		filename = name;
		line = 1;
		column = 1;
		tab_width = 8;
		token = null;
                next = null;
                backchar = 0;
	}

	/*
	 * Read a character from a file, using UTF-8 encoding.
	 * Also track the line and column numbers.
	 */
	wchar file_getc ()
	{
		wchar c;

		if (backchar) {
			c = backchar;
			backchar = 0;
		} else {
			c = file.getc();
			if (c & 0x80) {
				uint c2 = file.getc();
				if (! (c & 0x20))
					c = (c & 0x1f) << 6 | (c2 & 0x3f);
				else {
					uint c3 = file.getc();
					c = (c & 0x0f) << 12 |
						(c2 & 0x3f) << 6 | (c3 & 0x3f);
				}
			}
		}
		switch (c) {
		default:
			column++;
			break;
		case '\n':
			line++;
			column = 1;
			break;
		case '\t':
			column += tab_width - 1;
			column = column / tab_width * tab_width + 1;
			break;
		case '\f':
		case '\r':
			break;
		}
		return c;
	}

	/*
	 * Put a character "back" into a file..
	 * Also decrease the line and column numbers.
	 */
	void file_ungetc (wchar c)
	{
		backchar = c;
		switch (c) {
		default:
			column--;
			break;
		case '\n':
			line--;
			break;
		case '\f':
		case '\r':
			break;
		}
	}

	/*
	 * Put current token "back" into an input stream.
	 */
	void back ()
	{
		if (token !is null) {
			next = token;
			token = null;
		}
	}

	/*
	 * Fetch next element from an input stream, ant put it into `token'.
	 */
	void forward ()
	{
		if (next !is null) {
			/* Return back token. */
			token = next;
			next = null;
			return;
		}
		token = null;
		for (;;) {
			/* Remember a line and column where this lexeme starts. */
			int lex_line = line;
			int lex_col = column;

			wchar c = file_getc();
			if (file.eof ()) {
				/* On end of file, return null token. */
				return;
			}
			switch (c) {
			case ' ':
			case '\n':
			case '\t':
			case '\f':
			case '\r':
				/* Skip spaces. */
				continue;
			case '+': case '-': case '*': case '%':
			case '(': case ')': case '[': case ']':
			case '=': case ',': case '.': case ':':
			case ';': case '?':
				token = new lexeme_t (c, [cast(char)c]);
				break;
                        case '/':
                                c = file_getc();
                                if (c == '/') {
                                        /* Skip comment to end-of-line. */
                                        while (! file.eof()) {
                                                if (file_getc() == '\n')
                                                        break;
                                        }
                                        continue;
                                }
                                file_ungetc (c);
                                token = new lexeme_t ('/', "/");
                                break;
			case '<':
				c = file_getc();
				if (c == '=') {
					token = new lexeme_t (LEX_LE, "<=");
				} else if (c == '>') {
					token = new lexeme_t (LEX_NEQ, "<>");
				} else {
					file_ungetc (c);
					token = new lexeme_t ('<', "<");
				}
				break;
			case '>':
				c = file_getc();
				if (c == '=') {
					token = new lexeme_t (LEX_GE, ">=");
				} else {
					file_ungetc (c);
					token = new lexeme_t ('>', ">");
				}
				break;
			case '0': case '1': case '2': case '3': case '4':
			case '5': case '6': case '7': case '8': case '9':
				number_constant (c);
				break;
			case '"':
				string_literal ();
				break;
			default:
				if (! isUniAlpha(c) && c != '_' && c != '~') {
					/* Invalid character, return token type -1. */
					token = new lexeme_t (-1,
						format ("Unexpected character %04x", c));
					break;
				}
				identifier (c);
				if (c == '~') {
					if (token.source.length < 2) {
						token = new lexeme_t (-1,
							format ("Invalid label"));
						break;
					}
					token.type = LEX_LABEL;
				}
				break;
			}

			/* We have a token. */
			token.line = lex_line;
			token.column = lex_col;
			return;
		}
	}

	/*
	 * Read identifier.
	 * Characters allowed: a-z, A-Z, 0-9, _
	 * Detect keywords.
	 */
	void identifier (wchar c)
	{
		wchar[] name;
		int len, n;
		int ident_char (wchar c) {
			return isUniAlpha(c) ||
				(c >= '0' && c <= '9') || c == '_';
		}

		len = 16;
		name = new wchar [len];
		n = 0;
		name [n++] = c;
		for (;;) {
			c = file_getc ();
			if (file.eof ())
				break;
			if (! ident_char (c)) {
				file_ungetc (c);
				break;
			}
			if (n >= name.length)
				name.length = n + 16;
			name [n++] = c;
		}
		name.length = n;

		/* Convert name[] to lower case. */
		wchar[] lowercase = name.dup;
		for (n=0; n<lowercase.length; ++n)
			lowercase[n] = toUniLower (lowercase[n]);

		token = new lexeme_t (LEX_NAME, toUTF8 (name));
		token.text = toUTF8 (lowercase);
	}

	/*
	 * Read number constant.
	 */
	void number_constant (wchar c)
	{
		string source;
		int len, n;
		int is_digit (wchar c) {
			return (c >= '0' && c <= '9');
		}
		void append_char (char c) {
			if (n >= source.length)
				source.length = n + 16;
			source [n++] = c;
		}

		len = 16;
		source.length = len;
		n = 0;
		while (c >= '0' && c <= '9' || c == '.') {
			append_char (c);
			c = file_getc ();
			if (file.eof ())
				goto done;
		}
		file_ungetc (c);
done:
		append_char ('\0');
		source.length = n;
		token = new lexeme_t (LEX_NUMBER, source);
		token.number = strtod (source.ptr, null);
	}

	void string_literal ()
	{
		wchar[] text;
		int len, n;

		len = 40;
		text = new wchar [len];
		n = 0;
		while (! file.eof ()) {
			wchar c = file_getc ();
			if (c == '\n') {
				/* Continuation line starts with bar. */
				while (! file.eof () && c != '|')
					c = file_getc ();
				continue;
			}
			if (c == '"') {
				/* Quote is encoded as two quotes. */
				if (file.eof ())
					break;
				c = file_getc ();
				if (c != '"') {
					/* End of string. */
					file_ungetc (c);
					break;
				}
			}
			if (n >= text.length)
				text.length = n + 40;
			text [n++] = c;
		}
		text.length = n;

		token = new lexeme_t (LEX_STRING, "");
		token.text = toUTF8 (text);
	}
}

debug (scanner) {
	void main()
	{
		scanner_t scanner;

		writefln ("Scanner unit test started.");
		scanner = new scanner_t ("scanner.test");
		for (;;) {
			scanner.forward ();
			if (! scanner.token)
				break;
			if (scanner.token.type < 0) {
				writefln ("%s:%d:%d: %s", scanner.filename,
					scanner.token.line, scanner.token.column,
					scanner.token.source);
				break;
			}
			scanner.token.print (0);
		}
		writefln ("Scanner unit test finished.");
	}
}
