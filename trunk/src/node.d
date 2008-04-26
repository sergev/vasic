module node;

import std.stdio;
import std.stream;
import std.string;
import parser;

/*
 * Узел синтаксического дерева.
 */
class node_t {
	int type;	/* Код типа узла */

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
		writefln ("(%d)", type);
	}
}

/*
 * Лексема входного файла.
 */
class lexeme_t : node_t {
	int line;	/* Номер строки входного файла */
	int column;	/* Номер позиции в строке входного файла */
	string text;	/* Что было прочитано из входного файла */

	this (int t, int l, int c, string txt) {
		type = t;
		line = l;
		column = c;
		text = txt;
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
		switch (type) {
		case NODE_AND:		writef ("AND");			break;
                case NODE_BREAK:	writef ("BREAK");		break;
                case NODE_CONTINUE:	writef ("CONTINUE");		break;
                case NODE_DO:		writef ("DO");			break;
                case NODE_EACH:		writef ("EACH");		break;
                case NODE_ELSE:		writef ("ELSE");		break;
                case NODE_ELSEIF:	writef ("ELSEIF");		break;
                case NODE_ENDDO:	writef ("ENDDO");		break;
                case NODE_ENDFUNCTION:	writef ("ENDFUNCTION");		break;
                case NODE_ENDIF:	writef ("ENDIF");		break;
                case NODE_ENDPROCEDURE:	writef ("ENDPROCEDURE");	break;
                case NODE_ENDTRY:	writef ("ENDTRY");		break;
                case NODE_EXCEPT:	writef ("EXCEPT");		break;
                case NODE_EXECUTE:	writef ("EXECUTE");		break;
                case NODE_EXPORT:	writef ("EXPORT");		break;
                case NODE_FOR:		writef ("FOR");			break;
                case NODE_FUNCTION:	writef ("FUNCTION");		break;
                case NODE_GOTO:		writef ("GOTO");		break;
                case NODE_IF:		writef ("IF");			break;
                case NODE_IN:		writef ("IN");			break;
                case NODE_NEW:		writef ("NEW");			break;
                case NODE_NOT:		writef ("NOT");			break;
                case NODE_OR:		writef ("OR");			break;
                case NODE_PROCEDURE:	writef ("PROCEDURE");		break;
                case NODE_RAISE:	writef ("RAISE");		break;
                case NODE_RETURN:	writef ("RETURN");		break;
                case NODE_THEN:		writef ("THEN");		break;
                case NODE_TO:		writef ("TO");			break;
                case NODE_TRY:		writef ("TRY");			break;
                case NODE_VAR:		writef ("VAR");			break;
                case NODE_WHILE:	writef ("WHILE");		break;
		case NODE_NAME:		writef ("NAME %s", text);	break;
		default:
			if (text.length > 0)
				writef ("%s ", text);
			writef ("(%d)", type);
			break;
		}
		if (line)
			writef (" (%d:%d)", line, column);
		writefln ("");
	}
}

/*
 * Числовая константа.
 */
class number_t : lexeme_t {
	double value;

	this (double v, int l, int c, string txt) {
		super (NODE_NUMBER, l, c, txt);
		value = v;
	}

	override void print (int offset)
	{
		for (int i=0; i<offset; ++i)
			printf ("    ");
		if (offset < 0)
			offset = -offset;
		if (! this) {
			writefln ("(null)");
			return;
		}
		writef ("NUMBER %g", value);
		if (line)
			writef (" (%d:%d)", line, column);
		writefln ("");
	}
}

/*
 * Узел с двумя ветвями.
 */
class binary_node_t : node_t {
	node_t left;
	node_t right;

	this (int t, node_t l=null, node_t r=null) {
		type = t;
		left = l;
		right = r;
	}

	/*
	 * Print a readable representation of the tree
	 * for debugging purposes.
	 */
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
		switch (type) {
		case NODE_COMMA:	writef ("COMMA");		break;
		case NODE_PROCEDURE:	writef ("PROCEDURE");		break;
		case NODE_FUNCTION:	writef ("FUNCTION");		break;
		case NODE_ARG:		writef ("ARG");			break;
		default:		writef ("(%d)", type);		break;
		}
		writefln ("");
		if (left)
			left.print (offset + 1);
		if (right)
			right.print (offset + 1);
	}
}
