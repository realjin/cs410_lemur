%option noyywrap
%option never-interactive
%option prefix="InQuery" 
%{

/*==========================================================================
 * Copyright (c) 2002 University of Massachusetts.  All Rights Reserved.
 *
 * Use of the Lemur Toolkit for Language Modeling and Information Retrieval
 * is subject to the terms of the software license set forth in the LICENSE
 * file included with this software, and also available at
 * http://www.lemurproject.org/license.html
 *
 *==========================================================================
*/

#include "InQueryOpParser.hpp"

#include <cstring>
#include <cctype>
#include <cstdlib>
#include <cstdio>
#include <iostream>
#include <fstream>

#define ON   1
#define OFF  0
#define WORD 2
#define LEFT_PAREN 3
#define RIGHT_PAREN 4
#define AND 7
#define BOOLEANAND 8
#define BOOLEANAND_NOT 9
#define FILTER_REQUIRE 10
#define FILTER_REJECT 11
#define FIELD_OP 12
#define LITERAL 13
#define MAX_OP 14
#define NOT 17
#define ODN 18
#define OR 19
#define PARSUMN 20
#define PHRASE 21
#define SUM 22
#define SYN 23
#define UWN 24
#define WSUM 25
#define NUMBER 26
#define QBEGIN 30
#define QBEGINT 33
#define QEND 31
#define PROP 32

/* PAREN OPERATIONS:
 * NL_LPAREN :   called when a left paren is seen.  If paren_stack is 
 *		empty, we're not inside an operator so this is a 
 *              Natural Language paren.  If paren_stack is not empty, 
 *		but PARENLEVEL is zero, then the paren we're seeing 
 *		is the operator's left paren; if the PARENLEVEL is > 0, 
 *		then again it's a natural language paren we're looking at.
 *              RESULT: returns 1 if this is a Natural Language left paren.
 *              SIDE EFFECT: increments PARENLEVEL
 * NL_RPAREN;   see above.
 *              RESULT: returns 1 if this is a Natural Language right paren.
 *		SIDE EFFECT: decrements PARENLEVEL
 */

int paren_stack[NESTING_LIMIT];
int paren_stack_top=0;
char wsize[30];
#define push_paren_stack(op) {paren_stack[paren_stack_top++]=op;}
#define pop_paren_stack() {if(paren_stack_top>0)paren_stack_top--;}
#define parseError(msg) {cout << msg << endl; exit(1); }

char * getsize() { 
  int l=yyleng; 
  strcpy(wsize, yytext); 
  while(!isdigit(wsize[l-1])) l--;  
  wsize[l]='\0';
  l=0;
  while(!isdigit(wsize[l])) l++; 
  return &wsize[l];
}


%}

%start LIT OP NEST

att     ([Aa][Tt][ ]?&[ ]?[Tt]|ATT)
alpha   ([a-zA-Z\300-\326\330-\366\370-\377])
num     ([0-9])
alphanum ({alpha}|{num})

w1      ({alpha}{alphanum}*)
w2      ({num}+{alpha}{alphanum}*)

s       ({num}+\.{alphanum}+(\.{alphanum}+)+)
a       (({alpha}+\.)+({alpha}+\.?)) 
b       ({alpha}{alphanum}*(\.{alphanum}+)+) 
h       ({alpha}+\-\n?{alphanum}+)
ch_char ([\200-\377][\001-\377])
     
wordobj	({w1}|{w2}|{s}|{a}|{b}|{h}|{ch_char}+)

es1     (["']?[;:\.\?\!][ \n\t]+)
es2     ([;:\.\?\!]["']?[ \n\t]+)
es      ({es1}|{es2})
eq      [;]
bq      \#?[Qq][0-9]*[ ]*\=[ ]*
bqt      \#?[Qq][0-9]*[ ]*\=[ ]*[^\#]

n1      ({num}+(\.{num}+)?)
n2      ({num}{1,3}(\,{num}{num}{num})+(\.{num}+)?)
n3	(\.{num}+)
numobj	({n1}|{n2}|{n3})

%%


<LIT>[^ \n\t\(\)]*\( { /* parens jammed together */
    push_paren_stack(LIT); 
    return LEFT_PAREN; 
}

<LIT>[^ \n\t\)\(]+\) { /* NL paren? */ /* words and parens jammed together */
  if(yyleng>1) {
    yytext[yyleng-1]='\0';
    yyless(yyleng-1);
    return WORD;
  }
}


<LIT,OP,NEST>[ \t\n]*\) {
  pop_paren_stack();
  if(paren_stack_top>0)
    BEGIN(paren_stack[paren_stack_top]);
  else 
   BEGIN(0);
  return RIGHT_PAREN;
}

<LIT>[^ \n\t\)\(]+ {
  return  WORD;
}

<LIT,OP,NEST>[ \t\n]  		{; /* delimiters */ }

<OP>\(			{
                            push_paren_stack(OP);
                            return LEFT_PAREN;
                          /* else just erase it */ }
<NEST>\(		{
                            push_paren_stack(NEST);
                            return LEFT_PAREN;
                          /* else just erase it */ }

!c!(.*)\n                 { /* Ignore comments */ }

#AND			|
#(A|a)nd		{ BEGIN(NEST);
                          return (AND); }
#BAND			|
#(B|b)and		{ BEGIN(NEST);
                          return (BOOLEANAND); }
#BANDNOT		|
#(B|b)(A|a)nd(n|N)ot	{ BEGIN(NEST);
                          return (BOOLEANAND_NOT); }

#FILTER_REQUIRE         |
#(F|f)ilter_(R|r)equire |
#FILREQ                 |
#(F|f)il(R|r)eq		{ BEGIN(NEST);
                          return (FILTER_REQUIRE); }
#FILTER_REJECT          |
#(F|f)ilter_(R|r)eject  |
#FILREJ                 |	 
#(F|f)il(R|r)ej		{ BEGIN(NEST);
                          return (FILTER_REJECT); }

#CITY			|
#(C|c)ity		|
#COMPANY		|
#(C|c)ompany		| 
#FOREIGNCOUNTRY		|
#(F|f)oreigncountry	| 
#LOCATION		|
#(L|l)ocation		|
\*[A-Za-z0-9\_\-]+      { 
			  /* User keyword/generics are prefixed with a 
			   * "*".   "#" is old-style, retained for 
			   * compatibility.
			   */

			  return  WORD; }

#FIELD                  |
#(F|f)ield              { /* field operator */
                          BEGIN(OP);
                          return (FIELD_OP);
                        }

#LIT                    |
#(L|l)it                { /* literal operator */
                          BEGIN LIT;
                          return(LITERAL);
                        }

#MAX			|
#(M|m)ax		{ BEGIN(NEST);
                          return (MAX_OP); }

#NOT			|
#(N|n)ot		{ BEGIN(NEST);
                          return (NOT); }

#OR			|
#(O|o)r			{ BEGIN(NEST);
                          return (OR); }

#PASSAGE[0-9]+		|
#(P|p)assage[0-9]+	{ 
			  BEGIN(NEST);
                          return (PARSUMN);
			}

#PHRASE		|
#(P|p)hrase	{ 
			  BEGIN(NEST);
                          return (PHRASE);
			}

#SUM			|
#(S|s)um		{ BEGIN(NEST);
                          return (SUM); }

#SYN			|
#(S|s)yn		{ BEGIN(NEST);
                          return (SYN); }

#((O|o)(d|D))?[0-9]+	{ 
			  BEGIN(NEST);
                          return (ODN);
			}
#(p|P)(r|R)(o|O)(p|P)	{ 
			  BEGIN(NEST);
                          return (PROP);
			}

#(U|u)(W|w)[0-9]+	{ BEGIN(NEST);
			  return (UWN);
			}

#WSUM			|
#(W|w)sum		{ BEGIN(NEST);
                          return (WSUM); }

{eq}                    { /* end of query token */
			  return QEND;
                        }

{bq}                    { /* begin query token */
			  return QBEGIN;
                        }

{bqt}                    { /* begin text query token */
                          yyless(yyleng-1);
			  return QBEGINT;
                        }

{numobj}		{
                          return (NUMBER);
			}

{wordobj}		{ 
                          return  WORD;
                        }

.|\n			{ /* Ignore unexpected stuff */ 
                        }

%%

lemur::parse::InQueryOpParser::InQueryOpParser() {
  state = 0;
  iden = identifier;
}

void lemur::parse::InQueryOpParser::finishing_nesting_qnote(int top) {
  int tok;
  while((tok=(int)InQuerylex())) {
    if(tok == RIGHT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("RPAREN");
      if(paren_stack_top == top)
	return;
    }
    else
      parseQryNode(tok);
  }
}


void lemur::parse::InQueryOpParser::parseNestingOp(char *op) {
  if (state) {
    int nxtok=InQuerylex();
    if (textHandler != NULL) textHandler->foundSymbol(op);
    if(nxtok == LEFT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      finishing_nesting_qnote(paren_stack_top-1);
    }
    else 
      parseError (" parseNestingOp: missing LEFT_PAREN");
  }
  return;
}

void lemur::parse::InQueryOpParser::finishing_prox_qnote(int top) {
  int tok;
  while((tok=(int)InQuerylex())) {
    if(tok == RIGHT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("RPAREN");
      if(paren_stack_top == top)
	return;
    }
    else
      parseProxNode(tok);
  }
}

void lemur::parse::InQueryOpParser::parseProxOp(char *op, char *size) {
  if (state) {
    int nxtok=InQuerylex();
    if (textHandler != NULL) {
      textHandler->foundSymbol(op);
      textHandler->foundSymbol(size);
    }
    if(nxtok == LEFT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      finishing_prox_qnote(paren_stack_top-1);
    }
    else 
      parseError (" parseProxOp: missing LEFT_PAREN");
  }
  return;
}

void lemur::parse::InQueryOpParser::parsePassageOp(char *op, char *size) {
  if (state) {
    int nxtok=InQuerylex();
    if (textHandler != NULL) {
      textHandler->foundSymbol(op);
      textHandler->foundSymbol(size);
    }
    if(nxtok == LEFT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      finishing_nesting_qnote(paren_stack_top-1);
    }
    else 
      parseError (" parseProxOp: missing LEFT_PAREN");
  }
  return;
}

void lemur::parse::InQueryOpParser::parseSynOp(char *op) {
  if (state) {
    int nxtok=InQuerylex();
    if (textHandler != NULL) {
      textHandler->foundSymbol(op);
    }
    if(nxtok == LEFT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      finishing_prox_qnote(paren_stack_top-1);
    }
    else 
      parseError (" parseProxOp: missing LEFT_PAREN");
  }
  return;
}

void lemur::parse::InQueryOpParser::parsePropOp(char *op) {
  if (state) {
    int nxtok=InQuerylex();
    if (textHandler != NULL) {
      textHandler->foundSymbol(op);
    }
    if(nxtok == LEFT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      finishing_prox_qnote(paren_stack_top-1);
    }
    else 
      parseError (" parsePropOp: missing LEFT_PAREN");
  }
  return;
}

void lemur::parse::InQueryOpParser::parseTermOp(char *op) {
  if (state) {
    int nxtok=InQuerylex();
    if (textHandler != NULL) textHandler->foundSymbol(op);
    if(nxtok == LEFT_PAREN) {
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      while((nxtok=(int)InQuerylex())) {
	switch(nxtok) {
	case NUMBER:
	case WORD:
	  if (textHandler != NULL) textHandler->foundWord(InQuerytext);
	  break;

	case LITERAL:
	  parseQryNode(nxtok);
	  break;

	case RIGHT_PAREN:
	  if (textHandler != NULL) textHandler->foundSymbol("RPAREN");
	  return;
	default:
	  parseError (" parseTermOp: Syntax error");
	}
      }
    }
    else 
      parseError (" parseTermOp: missing LEFT_PAREN");
  }
  return;
}

void lemur::parse::InQueryOpParser::parseProxNode(int tok) {
  int l;
  switch(tok) {
    case NUMBER:         
    case WORD:
      if (state) {
        // convert word to lowercase and pass it on
	for (char * c = InQuerytext; *c != '\0'; c++)
	  *(c) = tolower(*c);
	if (textHandler != NULL) textHandler->foundWord(InQuerytext);
      }
      return;
      break;

    case ODN:
      parseProxOp("#ODN", getsize());
      break;

    case SYN:
      parseSynOp("#SYN");
      break;

    case UWN:
      parseProxOp("#UWN", getsize());
      break;

  case PROP:
    parsePropOp("#PROP"); // should have its own parse method.
      break;
  
  default:
    parseError ("parseProxNode: PARSE ERROR: proximity op allows only prox child");
    }
}


void lemur::parse::InQueryOpParser::parseQryNode(int tok) {
  int l;
  switch(tok) {
    case NUMBER:         
    case WORD:
      if (state) {
        // convert word to lowercase and pass it on
	for (char * c = InQuerytext; *c != '\0'; c++)
	  *(c) = tolower(*c);
	if (textHandler != NULL) textHandler->foundWord(InQuerytext);
      }
      return;
      break;

    case AND:
      parseNestingOp("#AND");
      break;
    case OR:
      parseNestingOp("#OR");
      break;
    case BOOLEANAND:
      parseNestingOp("#BAND");
      break;
    case BOOLEANAND_NOT:
      parseNestingOp("#BANDNOT");
      break;
    case FILTER_REQUIRE:
      parseNestingOp("#FILTREQ");
      break;

    case FILTER_REJECT:
      parseNestingOp("#FILTREJ");
      break;

    case FIELD_OP:
      parseTermOp("#FIELD");
      break;

    case LITERAL:
      if (state) {
	// useless in Lemur because of no such an indexed term
	int nxtok=(int)InQuerylex();
	if (textHandler != NULL) textHandler->foundSymbol("#LIT");
	if(nxtok == LEFT_PAREN) {
	  if (textHandler != NULL) {
	    textHandler->foundSymbol("LPAREN");
	    if((nxtok=InQuerylex())==WORD)
	      textHandler->foundSymbol(InQuerytext);
	    else
	      parseError ("parseQryNode: #lit needs a term");
	  }
	}
	else
	  parseError ("parseQryNode: #lit needs LEFT_PAREN");
      }
      return;
      break;

    case MAX_OP:
      parseNestingOp("#MAX");
      break;

    case NOT:
      parseNestingOp("#NOT");
      break;

    case ODN:
      parseProxOp("#ODN", getsize());
      break;

    case SYN:
      parseSynOp("#SYN");
      break;

    case UWN:
      parseProxOp("#UWN", getsize());
      break;

    case PARSUMN:
      parsePassageOp("#PASSAGE", getsize());
      break;

    case PHRASE:
      parseProxOp("#ODN", "3");
      break;

    case SUM:
      parseNestingOp("#SUM");
      break;

    case WSUM:
      if (state) {
	int tok, wsum_top;
	if (textHandler != NULL) textHandler->foundSymbol("#WSUM");
	tok=(int)InQuerylex();
	if(tok == LEFT_PAREN) {
	  if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
	  wsum_top=paren_stack_top-1;
	  while((tok=(int)InQuerylex())) {
	    if(tok == RIGHT_PAREN) {
	      if (textHandler != NULL) textHandler->foundSymbol("RPAREN");
	      if(paren_stack_top == wsum_top)
		return;
	      else
		parseError ("parseQryNode: #WSUM unmatched paren");
	    }
	    else if(tok == NUMBER) {
	      // Syntax: #WSUM(w1 q1 w2 q2 ... wn qn)
	      if (textHandler != NULL) textHandler->foundWord(InQuerytext);
	      tok=(int)InQuerylex();
	      parseQryNode(tok);
	    }
	    else
	      parseError ("parseQryNode: #WSUM syntax error");
	  }
	}
	else
	  parseError ("parseQryNode: #WSUM needs a LEFT_PAREN");
      }
      break;
  case PROP:
    parsePropOp("#PROP"); // should have its own parse method.
      break;
  
  default:
      parseError ("parseQryNode: PARSE ERROR: unknown token");
    }
}

long lemur::parse::InQueryOpParser::fileTell() const {
  int offset = yy_c_buf_p-YY_CURRENT_BUFFER->yy_ch_buf;
  if (InQueryin) {
    long begin = ftell(InQueryin)-YY_CURRENT_BUFFER->yy_n_chars;
    return begin+offset;
  } 
  return offset;
}


void lemur::parse::InQueryOpParser::parseBuffer(char* buf, int len) {
  yy_scan_bytes(buf, len);
  doParse();
}

void lemur::parse::InQueryOpParser::parseFile(const string &filename) {
  parsefile=filename;
  InQueryin = fopen(filename.c_str(), "rb");
  doParse();
  fclose(InQueryin);
}

void lemur::parse::InQueryOpParser::doParse() {
  
  int tok;
  // The core loop of the parser.
  // The parser is state based.  Encountering an op 
  // can transition the machine into another state.
  while (tok = InQuerylex()) {
    switch (tok) {	
    case QEND:
      // end of a query
      if(paren_stack_top>0)
	parseError ("parse: PARSE ERROR: unmatched paren");
      state = 0;
      break;
      
    case QBEGIN: {
      // start a new query, its id is treated as a docid
      char * qid=strdup(InQuerytext);
      char *tofree=qid;
      int ql = strlen(InQuerytext);
      state = 1;
      while(*qid && !isdigit(*qid))
	qid++;
      while(ql > 0 && !isdigit(tofree[ql-1]))
	tofree[--ql]='\0';
      paren_stack_top=0;
      if (textHandler != NULL) textHandler->foundDoc(qid);
      free(tofree);
      break;
    }

    case QBEGINT: {
      // start a new query, its id is treated as a docid
      // It doesn't start with an operator, so wrap it in a #SUM
      char * qid=strdup(InQuerytext);
      char *tofree=qid;
      int ql = strlen(InQuerytext);
      state = 1;
      while(*qid && !isdigit(*qid))
	qid++;
      while(ql > 0 && !isdigit(tofree[ql-1]))
	tofree[--ql]='\0';
      paren_stack_top=0;
      if (textHandler != NULL) textHandler->foundDoc(qid);
      free(tofree);
      if (textHandler != NULL) textHandler->foundSymbol("#SUM");
      if (textHandler != NULL) textHandler->foundSymbol("LPAREN");
      while((tok = InQuerylex())) {
	if (tok == QEND) {	  
	  if (textHandler != NULL) textHandler->foundSymbol("RPAREN");
	  state = 0;
	  break;
	} else {
	  parseQryNode(tok);
	}
      }
    
    break;
    }
    default:
      parseQryNode(tok);
    }
  }
}
