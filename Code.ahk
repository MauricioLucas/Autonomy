#NoEnv

/*
Basic AHK Grammar
-----------------

EBNF as defined by "http://en.wikipedia.org/wiki/Extended_Backus-Naur_Form":

(* basic nonterminals *)
Whitespace  = " " | "\t"

(* fundemental types *)
Digit       = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' ;
DigitNumber = Digit , { Digit } ;
HexDigit    = 'a' | 'b' | 'c' | 'd' | 'e' | 'f' | 'A' | 'B' | 'C' | 'D' | 'E' | 'F' | Digit ;
Integer     = [ '+' | '-' ] , ( DigitNumber | ( '0x' , HexDigit , { HexDigit } ) ) ;
Decimal     = [ '+' | '-' ] , ( ( Digit , { Digit } , '.' , { Digit } ) | ( '.' , Digit , { Digit } ) ) ;
String      = '"' , { '""' | ? any character ? } , '"' ;
AlNum       = 'a' | 'b' | 'c' | 'd' | 'e' | 'f' | 'g' | 'h' | 'i' | 'j' | 'k' | 'l' | 'm' | 'n' | 'o' | 'p' | 'q' | 'r' | 's' | 't' | 'u' | 'v' | 'w' | 'x' | 'y' | 'z' | 'A' | 'B' | 'C' | 'D' | 'E' | 'F' | 'G' | 'H' | 'I' | 'J' | 'K' | 'L' | 'M' | 'N' | 'O' | 'P' | 'Q' | 'R' | 'S' | 'T' | 'U' | 'V' | 'W' | 'X' | 'Y' | 'Z' | Digit | '_' ;
Identifier  = AlNum , { AlNum } ;
Operand     = Integer | Decimal | String | Identifier

(* operators *)
Prefix      = "!" | "~" | "&" | "*" | "++" | "--" ;
Infix       = "||" | "&&" | "==" | "=" | "<>" | "!=" | ">" | "<" | ">=" | "<=" | ( Whitespace , "." , Whitespace ) | "&" | "^" | "|" | "<<" | ">>" | "+" | "-" | "*" | "/" | "//" | "." | ":=" | "+=" | "-=" | "*=" | "/=" | "//=" | ".=" | "|=" | "&=" | "^=" | "<<=" | ">>=" | "**" ;
Postfix     = "++" | "--"
Dynamic     = [ Identifier ] , "%" , Identifier , "%" , [ Identifier ] , { "%" , Identifier , "%" , [ Identifier ] } ;

(* expression components *)
Padding     = [ { Whitespace } ]
Operation   = ( Prefix , Padding , Operand ) | ( Operand , Padding , Infix , Padding , Operand ) | ( Operand , Padding , Postfix ) ;
Expression  = Padding , Operation , Padding , { Operation , Padding }

Syntax Element Table Format
---------------------------

[Operator]:          the symbol representing the operator     [Object]
	- Precedence:    the operator's precendence               [Integer]
	- Associativity: the associativity of the operator        [String: "L" or "R"]
	- Arity:         the number of operands the operator uses [Integer]

Token Types Enumeration
-----------

- OPERATOR:       0
- LITERAL_NUMBER: 1
- LITERAL_STRING: 2
- SEPARATOR:      3
- PARENTHESIS:    4
- OBJECT_BRACE:   5
- BLOCK_BRACE:    6
- LABEL:          7
- STATEMENT:      8
- IDENTIFIER:     9
- LINE_END:       10
*/

;initializes resources that will be required by the code tools
CodeInit(ResourcesPath = "Resources")
{ ;returns 1 on failure, nothing otherwise
 global CodeOperatorTable, CodeErrorMessages, CodeTokenTypes

 ;ensure the path ends with a directory separator ;wip: not cross-platform
 If (SubStr(ResourcesPath,0) <> "\")
  ResourcesPath .= "\"

 If (FileRead(Temp1,ResourcesPath . "OperatorTable.txt") <> 0) ;error reading file
  Return, 1

 ;parse operators table file into object
 CodeOperatorTable := Object()
 Loop, Parse, Temp1, `n, `r
  Line := StringSplit(A_LoopField,"`t"), ObjInsert(CodeOperatorTable,Line.1,Object("Precedence",Line.2,"Associativity",Line.3,"Arity",Line.4))

 If (FileRead(Temp1,ResourcesPath . "Errors.txt") <> 0) ;error reading file
  Return, 1

 ;parse error message file into object, and enumerate error identifiers
 CodeErrorMessages := Object()
 Loop, Parse, Temp1, `n, `r
  Line := StringSplit(A_LoopField,"`t"), ObjInsert(CodeErrorMessages,Line.1,Line.2)

 ;set up token type enumeration
 Temp1 := "OPERATOR|LITERAL_NUMBER|LITERAL_STRING|SEPARATOR|PARENTHESIS|OBJECT_BRACE|BLOCK_BRACE|LABEL|STATEMENT|IDENTIFIER|LINE_END"
 CodeTokenTypes := Object(), Index := 0
 Loop, Parse, Temp1, |
  ObjInsert(CodeTokenTypes,A_LoopField,Index), Index ++
}