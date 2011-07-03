#NoEnv

/*
Token Stream Format
-------------------

* _[Index]_:    the index of the token                         _[Object]_
    * Type:     the type of the token                          _[Identifier]_
    * Value:    the value of the token                         _[String]_
    * Position: position of token within the file              _[Integer]_
    * File:     the file index the current token is located in _[Integer]_

Example Token Stream
--------------------

    2:
        Type: IDENTIFIER
        Value: SomeVariable
        Position: 15
        File: 3
*/

;initializes resources that the lexer requires
CodeLexInit()
{
 global CodeOperatorTable, LexerEscapeChar, LexerIdentifierChars, LexerStatementList, LexerStatementLiteralList, LexerOperatorMaxLength

 LexerEscapeChar := "``" ;the escape character
 LexerIdentifierChars := "abcdefghijklmnopqrstuvwxyz_1234567890#" ;characters that make up a an identifier
 LexerStatementList := "#Include`n#IncludeAgain`n#SingleInstance`n#Warn`n#Define`nWhile`nLoop`nFor`nIf`nElse`nBreak`nContinue`nReturn`nGosub`nGoto`nlocal`nglobal`nstatic" ;statements that can be found on the beginning of a line
 LexerStatementLiteralList := "#Include`n#IncludeAgain`n#SingleInstance`n#Warn`n#Define`nBreak`nContinue`nGosub`nGoto" ;statements that accept literals as parameters

 ;convert statements string list to an object
 Temp1 := LexerStatementList, LexerStatementList := Object()
 Loop, Parse, Temp1, `n
  ObjInsert(LexerStatementList,A_LoopField,"")

 ;convert statements string list to an object
 Temp1 := LexerStatementLiteralList, LexerStatementLiteralList := Object()
 Loop, Parse, Temp1, `n
  ObjInsert(LexerStatementLiteralList,A_LoopField,"")

 LexerOperatorMaxLength := 1 ;one is the maximum length of the other syntax elements - commas, parentheses, square brackets, and curly brackets
 For Temp1 In CodeOperatorTable
  Temp2 := StrLen(Temp1), (Temp2 > LexerOperatorMaxLength) ? (LexerOperatorMaxLength := Temp2) : ""
}

;lexes AHK code, including all syntax
CodeLex(ByRef Code,ByRef Tokens,ByRef Errors,ByRef FileName = "")
{ ;returns 1 on error, nothing otherwise
 global CodeTokenTypes, CodeFiles, LexerIdentifierChars
 FileIndex := ObjMaxIndex(CodeFiles), (FileIndex = "") ? (FileIndex := 1) : (FileIndex ++) ;get the index to insert the file entry at
 ObjInsert(CodeFiles,FileIndex,FileName) ;add the current script file to the file array

 Tokens := Object(), Errors := Object(), Position := 1 ;initialize variables
 Loop
 {
  CurrentChar := SubStr(Code,Position,1)
  If (CurrentChar = "") ;past the end of the string
   Break
  CurrentTwoChar := SubStr(Code,Position,2), Position1 := Position
  If (CurrentChar = "`r" || CurrentChar = "`n" || A_Index = 1) ;beginning of a line
  {
   While, (InStr("`r`n`t ",CurrentChar := SubStr(Code,Position,1)) && (CurrentChar <> "")) ;move past any whitespace
    Position ++
   If (SubStr(Code,Position,1) = ";") ;single line comment
    CodeLexSingleLineComment(Code,Position) ;skip over comment
   Else ;input is a multiline comment or normal line
   {
    If (SubStr(Code,Position,2) = "/*") ;begin multiline comment
    {
     CodeLexMultilineComment(Code,Position) ;skip over the comment block
     While, ((CurrentChar := SubStr(Code,Position,1)) = "`r" || CurrentChar = "`n") ;move past any whitespace, to ensure there are no duplicate lines
      Position ++
    }
    ObjInsert(Tokens,Object("Type",CodeTokenTypes.LINE_END,"Value","","Position",Position - 1,"File",FileIndex)) ;add the statement end to the token array
    CodeLexLine(Code,Position,Tokens,Errors,FileIndex) ;check for statements
   }
  }
  Else If (CurrentChar = """") ;begin literal string
   CodeLexString(Code,Position,Tokens,Errors,Output,FileIndex)
  Else If (CurrentTwoChar = "/*") ;begin multiline comment
   CodeLexMultilineComment(Code,Position) ;skip over the comment block
  Else If (CurrentTwoChar = "*/") ;end multiline comment
   Position += 2 ;can be skipped over
  Else If (CurrentChar = "%") ;dynamic variable reference or dynamic function call
   CodeLexDynamicReference(Code,Position,Tokens,Errors,Output,FileIndex)
  Else If (CurrentChar = ".") ;object access (explicit handling ensures that Var.123.456 will have the purely numerical keys interpreted as identifiers instead of numbers)
  {
   ObjInsert(Tokens,Object("Type",CodeTokenTypes.OPERATOR,"Value",".","Position",Position,"File",FileIndex)) ;add a object access token to the token array
   Position ++, CurrentChar := SubStr(Code,Position,1) ;move to next char
   If (CurrentChar = " " || CurrentChar = "`t") ;object access operator cannot be followed by whitespace
    ObjInsert(Errors,Object("Identifier","INVALID_OBJECT_ACCESS","Level","Error","Highlight",Object("Position",Position1,"Length",Position - Position1),"Caret",Position,"File",FileIndex)) ;add an error to the error log
   CodeLexIdentifier(Code,Position,Tokens,FileIndex) ;lex identifier
  }
  Else If (CurrentChar = " " || CurrentChar = "`t") ;whitespace
  {
   Position ++, CurrentChar := SubStr(Code,Position,1) ;skip over whitespace, retrieve character from updated position
   If (CurrentChar = ";") ;single line comment
    CodeLexSingleLineComment(Code,Position) ;skip over comment
   Else If (CurrentChar = ".") ;concatenation operator (whitespace preceded it)
   {
    ObjInsert(Tokens,Object("Type",CodeTokenTypes.OPERATOR,"Value"," . ","Position",Position,"File",FileIndex)), Position ++ ;add a concatenation token to the token array, move past dot operator
    CurrentChar := SubStr(Code,Position,1)
    If !(CurrentChar = " " || CurrentChar = "`t") ;there must be whitespace on both sides of the concat operator
     ObjInsert(Errors,Object("Identifier","INVALID_CONCATENATION","Level","Error","Highlight",Object("Position",Position1,"Length",Position - Position1),"Caret",Position,"File",FileIndex)) ;add an error to the error log
   }
  }
  Else If !CodeLexSyntaxElement(Code,Position,Tokens,FileIndex) ;input is a syntax element
  {
   
  }
  Else If (InStr("1234567890",CurrentChar) && !CodeLexNumber(Code,Position,Output)) ;a number, not an identifier
   ObjInsert(Tokens,Object("Type",CodeTokenTypes.LITERAL_NUMBER,"Value",Output,"Position",Position1,"File",FileIndex)) ;add the number literal to the token array
  Else If InStr(LexerIdentifierChars,CurrentChar) ;an identifier
   CodeLexIdentifier(Code,Position,Tokens,FileIndex)
  Else ;invalid character
  {
   ObjInsert(Errors,Object("Identifier","INVALID_CHARACTER","Level","Error","Highlight","","Caret",Position,"File",FileIndex)) ;add an error to the error log
   Position ++
  }
 }
 Temp1 := Tokens[ObjMaxIndex(Tokens)] ;get most recent token
 If (Temp1.Type <> "LINE_END") ;token was not a newline
  ObjInsert(Tokens,Object("Type",CodeTokenTypes.LINE_END,"Value","","Position",Position,"File",FileIndex)) ;add the statement end to the token array
 Return, !!ObjMaxIndex(Errors) ;indicate whether or not there were errors
}

;lexes a new line, to find control structures, directives, etc.
CodeLexLine(ByRef Code,ByRef Position,ByRef Tokens,ByRef Errors,ByRef FileIndex)
{ ;returns 1 if the line cannot be lexed as a statement, nothing otherwise
 global CodeTokenTypes, LexerIdentifierChars, LexerStatementList, LexerStatementLiteralList

 ;store the candidate statement
 Position1 := Position, Statement := ""
 Loop
 {
  CurrentChar := SubStr(Code,Position,1)
  If ((CurrentChar = "") || !InStr(LexerIdentifierChars,CurrentChar))
   Break
  Statement .= CurrentChar, Position ++
 }

 ;detect labels
 If ((CurrentChar = ":") && InStr("`r`n`t ",SubStr(Code,Position + 1,1))) ;is a label
 {
  Position ++
  While, (InStr("`t ",CurrentChar := SubStr(Code,Position,1)) && (CurrentChar <> "")) ;move past whitespace
   Position ++
  ObjInsert(Tokens,Object("Type",CodeTokenTypes.LABEL,"Value",Statement,"Position",Position1,"File",FileIndex)) ;add the label to the token array
  Return
 }

 ;determine whether the line should be processed as an expression instead of a statement
 If !(InStr("`r`n`t, ",SubStr(Code,Position,1)) && ObjHasKey(LexerStatementList,Statement)) ;not a statement, so must be expression
 {
  Position := Position1 ;move the position back to the beginning of the line, to allow it to be processed again as an expression
  Return, 1
 }

 ObjInsert(Tokens,Object("Type",CodeTokenTypes.STATEMENT,"Value",Statement,"Position",Position1,"File",FileIndex)) ;add the statement to the token array

 ;line is a statement, so skip over whitespace, and up to one comma
 Temp1 := ","
 While, (InStr("`t " . Temp1,CurrentChar := SubStr(Code,Position,1)) && CurrentChar <> "")
  Position ++, (CurrentChar = ",") ? (Temp1 := "") : ""

 If (Statement = "For") ;handle For loops as a special case
  Return, CodeLexForLoop(Code,Position,Tokens,Errors,FileIndex)

 If ObjHasKey(LexerStatementLiteralList,Statement) ;the current statement accepts the parameters literally
 {
  ;extract statement parameters
  Parameters := "", Position1 := Position
  While, !InStr("`r`n",CurrentChar := SubStr(Code,Position,1))
   Position ++, Parameters .= CurrentChar

  ObjInsert(Tokens,Object("Type",CodeTokenTypes.LITERAL_STRING,"Value",Parameters,"Position",Position1,"File",FileIndex)) ;add the statement parameters to the token array
 }
}

;lexes a for loop
CodeLexForLoop(ByRef Code,ByRef Position,ByRef Tokens,ByRef Errors,ByRef FileIndex)
{
 global CodeTokenTypes, LexerIdentifierChars

 ;lex the variable that receives the key, or give an error if it is not valid
 If InStr(LexerIdentifierChars,SubStr(Code,Position,1)) ;valid identifier
  CodeLexIdentifier(Code,Position,Tokens,FileIndex)
 Else
 {
  ObjInsert(Errors,Object("Identifier","INVALID_IDENTIFIER","Level","Error","Highlight","","Caret",Position,"File",FileIndex)) ;add an error to the error log
  Return, 1
 }

 While, (InStr("`t ",CurrentChar := SubStr(Code,Position,1)) && CurrentChar <> "") ;skip over whitespace
  Position ++

 If (SubStr(Code,Position,1) = ",") ;variable that receives the value was given
 {
  Position ++ ;move past the comma

  While, (InStr("`t ",CurrentChar := SubStr(Code,Position,1)) && CurrentChar <> "") ;skip over whitespace
   Position ++

  ;lex the variable that receives the value, or give an error if it is not valid
  If InStr(LexerIdentifierChars,SubStr(Code,Position,1)) ;valid identifier
   CodeLexIdentifier(Code,Position,Tokens,FileIndex)
  Else
  {
   ObjInsert(Errors,Object("Identifier","INVALID_IDENTIFIER","Level","Error","Highlight","","Caret",Position,"File",FileIndex)) ;add an error to the error log
   Return, 1
  }

  While, (InStr("`t ",CurrentChar := SubStr(Code,Position,1)) && CurrentChar <> "") ;skip over whitespace
   Position ++
 }

 ;make sure the "In" keyword follows immediately after
 If !(SubStr(Code,Position,2) = "In" && InStr("`t ",CurrentChar := SubStr(Code,Position + 2,1)) && CurrentChar <> "")
 {
  ObjInsert(Errors,Object("Identifier","INVALID_FOR_LOOP","Level","Error","Highlight","","Caret",Position,"File",FileIndex)) ;add an error to the error log
  Return, 1
 }

 ObjInsert(Tokens,Object("Type",CodeTokenTypes.SEPARATOR,"Value",",","Position",Position,"File",FileIndex)) ;add a separator to the token array
 Position += 3 ;skip over the "In" keyword

 While, (InStr("`t ",CurrentChar := SubStr(Code,Position,1)) && CurrentChar <> "") ;skip over whitespace
  Position ++
}

;lexes a quoted string, handling escaped characters
CodeLexString(ByRef Code,ByRef Position,ByRef Tokens,ByRef Errors,ByRef Output,ByRef FileIndex) ;input code, current position in code, output to store the detected string in, name of input file
{ ;returns 1 on error, nothing otherwise
 global CodeTokenTypes, LexerEscapeChar
 Position1 := Position, Output := "", Position ++ ;move to after the opening quotation mark
 Loop
 {
  CurrentChar := SubStr(Code,Position,1)
  If (CurrentChar = LexerEscapeChar) ;next character is escaped
   Output .= SubStr(Code,Position,2), Position += 2 ;append the escape sequence to the output, and move past it
  Else If (CurrentChar = "" || InStr("`r`n",CurrentChar)) ;past end of string, or reached a newline before the open quote has been closed
  {
   ObjInsert(Errors,Object("Identifier","UNMATCHED_QUOTE","Level","Error","Highlight",Object("Position",Position1,"Length",Position - Position1),"Caret",Position,"File",FileIndex)) ;add an error to the error log
   Return, 1
  }
  Else If (CurrentChar = """") ;closing quote mark found
   Break
  Else ;string contents
   Output .= CurrentChar, Position ++ ;append the character to the output
 }
 Position ++ ;move to after the closing quotation mark
 ObjInsert(Tokens,Object("Type",CodeTokenTypes.LITERAL_STRING,"Value",Output,"Position",Position1,"File",FileIndex)) ;add the string literal to the token array
}

;lexes a single line comment
CodeLexSingleLineComment(ByRef Code,ByRef Position)
{
 Position ++ ;skip over semicolon
 While, !InStr("`r`n",SubStr(Code,Position,1)) ;loop until a newline is found
  Position ++
}

;lexes a multiline comment, including any nested comments it may contain
CodeLexMultilineComment(ByRef Code,ByRef Position)
{
 global LexerEscapeChar
 CommentLevel := 1
 While, CommentLevel ;loop until the comment has ended
 {
  Position ++
  CurrentChar := SubStr(Code,Position,1), CurrentTwoChar := SubStr(Code,Position,2)
  If (CurrentChar = "")
   Return
  If (CurrentChar = LexerEscapeChar) ;an escaped character in the comment
   Position += 2 ;skip over the entire esape sequence (allows escaping of comment chars: /* Some `/* Comment */)
  Else If (CurrentTwoChar = "/*") ;found a nested comment
   CommentLevel ++
  Else If (CurrentTwoChar = "*/") ;found a closing comment
   CommentLevel --
 }
 Position += 2 ;skip over the closing comment
}

;lexes dynamic variable and function references
CodeLexDynamicReference(ByRef Code,ByRef Position,ByRef Tokens,ByRef Errors,ByRef Output,ByRef FileIndex)
{ ;returns 1 on error, nothing otherwise
 global CodeTokenTypes, LexerIdentifierChars
 Output := "", Position1 := Position
 Loop
 {
  Position ++, CurrentChar := SubStr(Code,Position,1)
  If (CurrentChar = "%") ;found percent sign
   Break
  If (CurrentChar = "" || InStr("`r`n",CurrentChar)) ;past end of string, or found newline before percent sign was matched
  {
   ObjInsert(Errors,Object("Identifier","UNMATCHED_PERCENT_SIGN","Level","Error","Highlight",Object("Position",Position1,"Length",Position - Position1),"Caret",Position1,"File",FileIndex)) ;add an error to the error log
   Return, 1
  }
  If !InStr(LexerIdentifierChars,CurrentChar) ;invalid character found
  {
   ObjInsert(Errors,Object("Identifier","INVALID_IDENTIFIER","Level","Error","Highlight",Object("Position",Position1,"Length",Position - Position1),"Caret",Position,"File",FileIndex)) ;add an error to the error log
   Return, 1
  }
  Output .= CurrentChar
 }
 Position ++ ;move past matching percent sign
 ObjInsert(Tokens,Object("Type",CodeTokenTypes.OPERATOR,"Value","%","Position",Position1,"File",FileIndex)) ;add the dereference operator to the token array
 ObjInsert(Tokens,Object("Type",CodeTokenTypes.IDENTIFIER,"Value",Output,"Position",Position1 + 1,"File",FileIndex)) ;add the identifier to the token array
}

;lexes a syntax token
CodeLexSyntaxElement(ByRef Code,ByRef Position,ByRef Tokens,ByRef FileIndex)
{ ;returns 1 on error, nothing otherwise
 global CodeOperatorTable, CodeTokenTypes, LexerOperatorMaxLength
 Temp1 := LexerOperatorMaxLength, Position1 := Position
 Loop, %LexerOperatorMaxLength% ;loop until a valid token is found or 
 {
  Output := SubStr(Code,Position,Temp1)
  If ObjHasKey(CodeOperatorTable,Output) ;found operator
   TokenType := CodeTokenTypes.OPERATOR
  Else If (Output = ",") ;found separator
   TokenType := CodeTokenTypes.SEPARATOR
  Else If (Output = "(" || Output = ")") ;found parenthesis
   TokenType := CodeTokenTypes.PARENTHESIS
  Else If (Output = "[" || Output = "]") ;found object braces
   TokenType := CodeTokenTypes.OBJECT_BRACE
  Else If (Output = "{" || Output = "}") ;found block braces
   TokenType := CodeTokenTypes.BLOCK_BRACE
  Else
  {
   Temp1 -- ;reduce the length of the input to be checked
   Continue
  }
  Position += StrLen(Output) ;move past the syntax element, making sure the position is not past the end of the file
  ObjInsert(Tokens,Object("Type",TokenType,"Value",Output,"Position",Position1,"File",FileIndex)) ;add the found syntax element to the token array
  Return
 }
 Return, 1 ;not an operator or syntax element
}

;lexes a number, and if it is not a valid number, notify that it may be an identifier
CodeLexNumber(ByRef Code,ByRef Position,ByRef Output)
{ ;returns 1 when parsing failed, nothing otherwise
 global LexerIdentifierChars
 Output := "", Position1 := Position, NumberChars := "1234567890", DecimalUsed := 0
 If (SubStr(Code,Position,2) = "0x") ;hexidecimal number
  DecimalUsed := 1, Position += 2, Output .= "0x", NumberChars .= "abcdefABCDEF" ;prevent the usage of decimals in hex numbers, skip over the identifying characters, append them to the number, and expand the valid number characters set
 Loop
 {
  CurrentChar := SubStr(Code,Position,1)
  If (CurrentChar = "") ;past end of string
   Return
  If InStr(NumberChars,CurrentChar) ;is a valid number character
   Output .= CurrentChar
  Else If (CurrentChar = ".") ;is a decimal point
  {
   If DecimalUsed ;input already had a decimal point, so is probably an identifier
   {
    Position := Position1 ;return the position back to the start of this section, to try to process it again as an identifier
    Return, 1
   }
   Output .= CurrentChar, DecimalUsed := 1 ;set a flag to show that a decimal point has been used
  }
  Else If InStr(LexerIdentifierChars,CurrentChar) ;notify if the code is a valid identifier char if it cannot be processed as a number
  {
   Position := Position1 ;return the position back to the start of this section, to try to parse it again as an identifier
   Return, 1
  }
  Else ;end of number
   Return
  Position ++
 }
}

;lexes an identifier
CodeLexIdentifier(ByRef Code,ByRef Position,ByRef Tokens,ByRef FileIndex)
{
 global CodeTokenTypes, LexerIdentifierChars
 Output := "", Position1 := Position
 Loop
 {
  CurrentChar := SubStr(Code,Position,1)
  If (CurrentChar = "" || !InStr(LexerIdentifierChars,CurrentChar)) ;past end of string, or found a character that was not part of the identifier
   Break
  Output .= CurrentChar, Position ++
 }
 ObjInsert(Tokens,Object("Type",CodeTokenTypes.IDENTIFIER,"Value",Output,"Position",Position1,"File",FileIndex)) ;add the identifier to the token array
}