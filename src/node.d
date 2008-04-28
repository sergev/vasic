module node;

import std.stdio;
import std.stream;
import std.string;
import parser;

/*
 * Узел синтаксического дерева.
 */
class node_t {
	void print_offset (int offset)
	{
		for (int i=0; i<offset; ++i)
			writef ("    ");
	}

	void print (int offset) {}
}

/*
 * Узел с двумя ветвями.
 */
class list_t : node_t {
	node_t left;
	node_t right;

	this (node_t l=null, node_t r=null) {
		left = l;
		right = r;
	}

	/*
	 * Print a readable representation of the tree
	 * for debugging purposes.
	 */
	override void print (int offset)
	{
		print_offset (offset);
		if (! this) {
			writefln ("(null)");
			return;
		}
		writefln ("LIST");
		if (offset < 0)
			offset = -offset;
		if (left)
			left.print (offset + 1);
		if (right)
			right.print (offset + 1);
	}
}

/*
 * Числовая константа.
 */
class number_t : node_t {
	double value;

	this (double v) {
		value = v;
	}

	override void print (int offset)
	{
		print_offset (offset);
		if (! this) {
			writefln ("(null)");
			return;
		}
		writefln ("NUMBER %g", value);
	}
}

/*
 * Объявление переменной.
 */
class name_t : node_t {
	string name;
	bool global;

	this (string n, bool exported) {
		name = n;
		global = exported;
	}

	override void print (int offset)
	{
		print_offset (offset);
		if (! this) {
			writefln ("(null)");
			return;
		}
		writefln ("NAME %s%s", name, global ? ", export" : "");
	}
}

/*
 * Формальный аргумент функции.
 */
class arg_t : node_t {
	string name;
	bool by_value;
	node_t default_value;

	this (string n, bool val, node_t defval) {
		name = n;
		by_value = val;
		default_value = defval;
	}

	override void print (int offset)
	{
		print_offset (offset);
		if (! this) {
			writefln ("(null)");
			return;
		}
		writef ("%s%s", by_value ? "value " : "", name);
		if (default_value) {
			writef (" = ");
			default_value.print (0);
		}
	}
}

/*
 * Объявление процедуры или функции.
 */
class function_t : node_t {
	string name;
	bool global;
	bool func;
	node_t arguments;
	node_t declarations;
	node_t operators;

	this (string n, bool exported, bool f, node_t args,
	    node_t decls, node_t ops) {
		name = n;
		global = exported;
		func = f;
		arguments = args;
		declarations = decls;
		operators = ops;
	}

	private void print_args (node_t node)
	{
		for (;;) {
			list_t list = cast(list_t) node;
			if (! list)
				break;
			print_args (list.left);
			writef (", ");
			node = list.right;
		}
		node.print (0);
	}

	private void print_decls (node_t node, int offset)
	{
		for (;;) {
			list_t list = cast(list_t) node;
			if (! list)
				break;
			print_decls (list.left, offset);
			node = list.right;
		}
		name_t name = cast(name_t) node;
		if (name) {
			print_offset (offset);
			writefln ("VAR %s%s", name.name,
				name.global ? ", export" : "");
		} else
			node.print (offset);
	}

	private void print_ops (node_t node, int offset)
	{
		for (;;) {
			list_t list = cast(list_t) node;
			if (! list)
				break;
			print_ops (list.left, offset);
			node = list.right;
		}
		node.print (offset);
	}

	override void print (int offset)
	{
		print_offset (offset);
		if (! this) {
			writefln ("(null)");
			return;
		}
		writef ("%s %s (", func ? "FUNCTION" : "PROCEDURE", name);
		if (arguments)
			print_args (arguments);
		writefln (")%s", global ? ", export" : "");
		if (offset < 0)
			offset = -offset;
		if (declarations)
			print_decls (declarations, offset + 1);
		if (operators)
			print_ops (operators, offset + 1);
	}
}
