module scanner;

import std.stdio;
import std.stream;
import std.string;
import std.uni;
import std.utf;
import node;
import parser;
private import std.c.stdlib;

/*
 * Lexical scanner.
 */
class scanner_t {
	lexeme_t token;
	private lexeme_t next;
	private wchar backchar;
	int line;
	int column;
	string filename;
	BufferedFile file;
	int tab_width = 8;

	/*
	 * Open a file for parsing.
	 */
	this (string name) {
		file = new BufferedFile (name);
		filename = name;
		line = 1;
		column = 1;
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
			token = next;
			next = null;
			return;
		}
		token = null;
		for (;;) {
			int line0 = line;
			int col0 = column;
			wchar c = file_getc();
			if (file.eof ()) {
				return;
			}
			switch (c) {
			case ' ':
			case '\n':
			case '\t':
			case '\f':
			case '\r':
				continue;
			case '/':
				c = file_getc();
				if (c == '/') {
					// Skip comment to end-of-line.
					while (! file.eof()) {
						if (file_getc() == '\n')
							break;
					}
					continue;
				}
				file_ungetc (c);
				token = new lexeme_t (NODE_DIV, line0, col0, "/");
				return;
			case '+':
				token = new lexeme_t (NODE_PLUS, line0, col0, "+");
				return;
			case '-':
				token = new lexeme_t (NODE_MINUS, line0, col0, "-");
				return;
			case '*':
				token = new lexeme_t (NODE_MUL, line0, col0, "*");
				return;
			case '%':
				token = new lexeme_t (NODE_MOD, line0, col0, "%");
				return;
			case '=':
				token = new lexeme_t (NODE_EQUAL, line0, col0, "=");
				return;
			case '<':
				c = file_getc();
				if (c == '=') {
					token = new lexeme_t (NODE_LE, line0, col0, "<=");
				} else if (c == '>') {
					token = new lexeme_t (NODE_NEQ, line0, col0, "<>");
				} else {
					file_ungetc (c);
					token = new lexeme_t (NODE_LT, line0, col0, "<");
				}
				return;
			case '>':
				c = file_getc();
				if (c == '=') {
					token = new lexeme_t (NODE_GE, line0, col0, ">=");
				} else {
					file_ungetc (c);
					token = new lexeme_t (NODE_GT, line0, col0, ">");
				}
				return;
			case '(':
				token = new lexeme_t (NODE_LPAR, line0, col0, "(");
				return;
			case ')':
				token = new lexeme_t (NODE_RPAR, line0, col0, ")");
				return;
			case '[':
				token = new lexeme_t (NODE_LBRA, line0, col0, "[");
				return;
			case ']':
				token = new lexeme_t (NODE_RBRA, line0, col0, "]");
				return;
			case ',':
				token = new lexeme_t (NODE_COMMA, line0, col0, ",");
				return;
			case '.':
				token = new lexeme_t (NODE_DOT, line0, col0, ".");
				return;
			case ':':
				token = new lexeme_t (NODE_COLON, line0, col0, ":");
				return;
			case ';':
				token = new lexeme_t (NODE_SEMICOLON, line0, col0, ";");
				return;
			case '?':
				token = new lexeme_t (NODE_QUESTION, line0, col0, "?");
				return;
			case '0': case '1': case '2': case '3': case '4':
			case '5': case '6': case '7': case '8': case '9':
				number_constant (c, line0, col0);
				return;
			case '"':
				string_literal (line0, col0);
				return;
			case '~':
				label (line0, col0);
				return;
			default:
				if (isUniAlpha(c) || c == '_') {
					identifier (c, line0, col0);
					return;
				}
				token = new lexeme_t (-1, line0, col0,
					format ("Unexpected character '%c'", c));
				return;
			}
		}
	}

	/*
	 * Read identifier.
	 * Characters allowed: a-z, A-Z, 0-9, _
	 * Detect keywords.
	 */
	void identifier (wchar c, int line0, int col0)
	{
		wchar[] name;
		int len, n;
		int ident_char (wchar c) {
			return isUniAlpha(c) ||
				(c >= '0' && c <= '9') || c == '_';
		}

		len = 16;
		name = new wchar [len];
		name.length = 16;
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

		int type;
		switch (toUTF8 (lowercase)) {
                case "and":		type = NODE_AND;	break;
                case "break":		type = NODE_BREAK;	break;
                case "continue":	type = NODE_CONTINUE;	break;
                case "do":		type = NODE_DO;		break;
                case "each":		type = NODE_EACH;	break;
                case "elseif":		type = NODE_ELSEIF;	break;
                case "else":		type = NODE_ELSE;	break;
                case "enddo":		type = NODE_ENDDO;	break;
                case "endfunction":	type = NODE_ENDFUNCTION; break;
                case "endif":		type = NODE_ENDIF;	break;
                case "endprocedure":	type = NODE_ENDPROCEDURE; break;
                case "endtry":		type = NODE_ENDTRY;	break;
                case "except":		type = NODE_EXCEPT;	break;
                case "execute":		type = NODE_EXECUTE;	break;
                case "export":		type = NODE_EXPORT;	break;
                case "for":		type = NODE_FOR;	break;
                case "function":	type = NODE_FUNCTION;	break;
                case "goto":		type = NODE_GOTO;	break;
                case "if":		type = NODE_IF;		break;
                case "in":		type = NODE_IN;		break;
                case "new":		type = NODE_NEW;	break;
                case "not":		type = NODE_NOT;	break;
                case "or":		type = NODE_OR;		break;
                case "procedure":	type = NODE_PROCEDURE;	break;
                case "raise":		type = NODE_RAISE;	break;
                case "return":		type = NODE_RETURN;	break;
                case "then":		type = NODE_THEN;	break;
                case "to":		type = NODE_TO;		break;
                case "try":		type = NODE_TRY;	break;
                case "var":		type = NODE_VAR;	break;
                case "while":		type = NODE_WHILE;	break;
                case "возврат":		type = NODE_RETURN;	break;
                case "вызватьисключение": type = NODE_RAISE;	break;
                case "выполнить":	type = NODE_EXECUTE;	break;
                case "для":		type = NODE_FOR;	break;
                case "если":		type = NODE_IF;		break;
                case "и":		type = NODE_AND;	break;
                case "из":		type = NODE_IN;		break;
                case "или":		type = NODE_OR;		break;
                case "иначе":		type = NODE_ELSE;	break;
                case "иначеесли":	type = NODE_ELSEIF;	break;
                case "исключение":	type = NODE_EXCEPT;	break;
                case "каждого":		type = NODE_EACH;	break;
                case "конецесли":	type = NODE_ENDIF;	break;
                case "конецпопытки":	type = NODE_ENDTRY;	break;
                case "конецпроцедуры":	type = NODE_ENDPROCEDURE; break;
                case "конецфункции":	type = NODE_ENDFUNCTION; break;
                case "конеццикла":	type = NODE_ENDDO;	break;
                case "не":		type = NODE_NOT;	break;
                case "новый":		type = NODE_NEW;	break;
                case "перейти":		type = NODE_GOTO;	break;
                case "перем":		type = NODE_VAR;	break;
                case "по":		type = NODE_TO;		break;
                case "пока":		type = NODE_WHILE;	break;
                case "попытка":		type = NODE_TRY;	break;
                case "прервать":	type = NODE_BREAK;	break;
                case "продолжить":	type = NODE_CONTINUE;	break;
                case "процедура":	type = NODE_PROCEDURE;	break;
                case "тогда":		type = NODE_THEN;	break;
                case "функция":		type = NODE_FUNCTION;	break;
                case "цикл":		type = NODE_DO;		break;
                case "экспорт":		type = NODE_EXPORT;	break;
		default:		type = NODE_NAME;	break;
		}
		token = new lexeme_t (type, line0, col0, toUTF8 (name));
	}

	/*
	 * Read number constant.
	 * Decimal:               [0-9]+
	 *      or  [0-9]+      ' [0-9]+
	 *      or  [0-9]* [dD] ' [0-9]+
	 *   Octal: [0-9]* [oO] ' [0-7]+
	 *     Hex: [0-9]* [hH] ' [0-9a-fA-F]+
	 *  Binary: [0-9]* [bB] ' [01]+
	 * Examples:
	 *	123	h'abc	o'765
	 *	8'0	8h'55	b'1101
	 *	d'567
	 * Underscore is allowed after apostrophe.
	 */
	void number_constant (wchar c, int line0, int col0)
	{
		string text;
		int len, n;
		int is_digit (wchar c) {
			return (c >= '0' && c <= '9');
		}
		void append_char (char c) {
			if (n >= text.length)
				text.length = n + 16;
			text [n++] = c;
		}

		len = 16;
		text.length = len;
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
		text.length = n;
		token = new number_t (strtod (text.ptr, null), line0, col0, text);
	}

	void string_literal (int line0, int col0)
	{
	}

	void label (int line0, int col0)
	{
	}
}

unittest {
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
				scanner.token.text);
			break;
		}
		scanner.token.print (0);
	}
}

debug (scanner) {
	void main()
	{
		writefln ("Scanner unit test finished.");
	}
}
