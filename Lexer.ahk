#NoEnv

#Include Code.ahk
#Include Resources/Token.ahk

/*
Copyright 2011-2012 Anthony Zhang <azhang9@gmail.com>

This file is part of Autonomy. Source code is available at <https://github.com/Uberi/Autonomy>.

Autonomy is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

;initializes resources that the lexer requires
CodeLexInit()
{
    global CodeOperatorTable, CodeLexerConstants, CodeLexerOperatorMaxLength
    CodeLexerConstants := Object("ESCAPE","``","SINGLE_LINE_COMMENT",";","MULTILINE_COMMENT_BEGIN","/*","MULTILINE_COMMENT_END","*/","SEPARATOR",",","IDENTIFIER","abcdefghijklmnopqrstuvwxyz_1234567890#")

    CodeLexerOperatorMaxLength := 1 ;one is the maximum length of the other syntax elements - commas, parentheses, square brackets, and curly brackets
    For Temp1 In CodeOperatorTable.NullDenotation ;get the length of the longest null denotation operator
        Temp2 := StrLen(Temp1), (Temp2 > CodeLexerOperatorMaxLength) ? (CodeLexerOperatorMaxLength := Temp2) : ""
    For Temp1 In CodeOperatorTable.LeftDenotation ;get the length of the longest left denotation operator
        Temp2 := StrLen(Temp1), (Temp2 > CodeLexerOperatorMaxLength) ? (CodeLexerOperatorMaxLength := Temp2) : ""
}

;lexes plain source code, including all syntax
CodeLex(ByRef Code,ByRef Errors,ByRef FileIndex = 1)
{ ;returns 1 on error, 0 otherwise
    global CodeTokenTypes, CodeLexerConstants
    Tokens := [], Position := 1 ;initialize variables
    CurrentChar := SubStr(Code,Position,1)
    If (CurrentChar = "") ;past the end of the string
        Return, 0
    CodeLexLine(Code,Position,Tokens) ;move past whitespace and comment lines
    Loop
    {
        CurrentChar := SubStr(Code,Position,1)
        If (CurrentChar = "") ;past the end of the string
            Break
        CurrentTwoChar := SubStr(Code,Position,2)
        If (CurrentChar = "`r" || CurrentChar = "`n") ;beginning of a line
        {
            Position1 := Position, Position ++ ;store the position, move past the newline character
            CodeLexLine(Code,Position,Tokens) ;move past whitespace and comment lines
            Tokens.Insert(CodeTokenLineEnd(Position1,FileIndex)) ;add the line end to the token array
        }
        Else If (CurrentChar = """") ;begin literal string
            CodeLexString(Code,Position,Tokens,Errors,FileIndex)
        Else If (CurrentChar = CodeLexerConstants.SINGLE_LINE_COMMENT) ;single line comment
            CodeLexSingleLineComment(Code,Position)
        Else If (CurrentTwoChar = CodeLexerConstants.MULTILINE_COMMENT_BEGIN) ;begin multiline comment
            CodeLexMultilineComment(Code,Position) ;skip over the comment block
        Else If (CurrentTwoChar = CodeLexerConstants.MULTILINE_COMMENT_END) ;end multiline comment
            Position += StrLen(CodeLexerConstants.MULTILINE_COMMENT_END) ;move past multiline comment end
        Else If (CurrentChar = "." && SubStr(Code,Position + 1,1) != ".") ;object access
            CodeLexObjectAccessOperator(Code,Position,Tokens,Errors,FileIndex)
        Else If (CurrentChar = " " || CurrentChar = "`t") ;whitespace
            Position ++ ;skip to the next character
        Else If !CodeLexSyntaxElement(Code,Position,Tokens,FileIndex) ;input is a syntax element
        {
            
        }
        Else If (InStr("1234567890",CurrentChar) && !CodeLexNumber(Code,Position,Tokens,FileIndex)) ;begins with a numerical digit and is not an identifier
        {
            
        }
        Else If InStr(CodeLexerConstants.IDENTIFIER,CurrentChar) ;an identifier
            CodeLexIdentifier(Code,Position,Tokens,FileIndex)
        Else ;invalid character
        {
            CodeRecordError(Errors,"INVALID_CHARACTER",3,FileIndex,Position)
            Position ++ ;move past the character
        }
    }
    Temp1 := ObjMaxIndex(Tokens) ;get the highest token index
    If (Tokens[Temp1].Type = CodeTokenTypes.LINE_END) ;last token is a newline
        ObjRemove(Tokens,Temp1,"") ;remove the last token
    Return, Tokens
}

;lexes lines with comments or whitespace
CodeLexLine(ByRef Code,ByRef Position,ByRef Tokens)
{
    global CodeTokenTypes, CodeLexerConstants
    Loop
    {
        If ((CurrentChar := SubStr(Code,Position,1)) = "`r" || CurrentChar = "`n" || CurrentChar = " " || CurrentChar = "`t") ;whitespace character
        {
            Position ++
            While, ((CurrentChar := SubStr(Code,Position,1)) = "`r" || CurrentChar = "`n" || CurrentChar = " " || CurrentChar = "`t") ;move past whitespace characters
                Position ++
        }
        Else If (CurrentChar = CodeLexerConstants.SINGLE_LINE_COMMENT) ;single line comment
            CodeLexSingleLineComment(Code,Position) ;skip over comment
        Else If ((CurrentChar := SubStr(Code,Position,2)) = CodeLexerConstants.MULTILINE_COMMENT_BEGIN) ;multiline comment begin
            CodeLexMultilineComment(Code,Position) ;skip over the comment block
        Else If (CurrentChar = CodeLexerConstants.MULTILINE_COMMENT_END) ;multiline comment end
            Position += StrLen(CodeLexerConstants.MULTILINE_COMMENT_END) ;move past multiline comment end
        Else ;normal line
            Break
    }
}

;lexes a quoted string, handling escaped characters
CodeLexString(ByRef Code,ByRef Position,ByRef Tokens,ByRef Errors,ByRef FileIndex)
{ ;returns 1 if the quotation mark was unmatched, 0 otherwise
    global CodeTokenTypes, CodeLexerConstants
    Position1 := Position, Output := "", Position ++ ;move to after the opening quotation mark
    Loop
    {
        CurrentChar := SubStr(Code,Position,1)
        If (CurrentChar = CodeLexerConstants.ESCAPE) ;next character is escaped
        {
            Position ++, NextChar := SubStr(Code,Position,1) ;get the next character
            ;handle the escaping of the end of a line
            If (NextChar = "`r")
            {
                If (SubStr(Code,Position + 1,1) = "`n")
                    Position ++ ;move to the next character
                Output .= CodeLexerConstants.ESCAPE . "n", Position ++ ;always concatenate with the newline character
            }
            Else If (NextChar = "`n")
                Output .= CodeLexerConstants.ESCAPE . "n", Position ++ ;append the escape sequence to the output, and move past it
            Else
                Output .= CodeLexerConstants.ESCAPE . NextChar, Position ++ ;append the escape sequence to the output, and move past it
        }
        Else If (CurrentChar = "`r" || CurrentChar = "`n" || CurrentChar = "") ;past end of string, or reached a newline before the open quote has been closed
        {
            CodeRecordError(Errors,"UNMATCHED_QUOTE",3,FileIndex,Position,1,[Object("Position",Position1,"Length",Position - Position1)])
            Return, 1
        }
        Else If (CurrentChar = """") ;closing quote mark found
            Break
        Else ;string contents
            Output .= CurrentChar, Position ++ ;append the character to the output
    }
    Position ++ ;move to after the closing quotation mark
    Tokens.Insert(CodeTokenString(Output,Position1,FileIndex)) ;add the string literal to the token array
    Return, 0
}

;lexes a single line comment
CodeLexSingleLineComment(ByRef Code,ByRef Position)
{
    Position ++ ;skip over the comment character
    While, ((CurrentChar := SubStr(Code,Position,1)) != "`r" && CurrentChar != "`n" && CurrentChar != "") ;loop until a newline is found or the end of the file is reached
        Position ++
}

;lexes a multiline comment, including any nested comments it may contain
CodeLexMultilineComment(ByRef Code,ByRef Position)
{
    global CodeLexerConstants
    CommentLevel := 1, Position += StrLen(CodeLexerConstants.MULTILINE_COMMENT_BEGIN) ;set the current comment level, move past the multiline comment beginning sequence
    While, (CommentLevel > 0) ;loop until the comment has ended
    {
        CurrentChar := SubStr(Code,Position,1), CurrentTwoChar := SubStr(Code,Position,2)
        If (CurrentChar = "") ;past the end of the string
            Return
        If (CurrentChar = CodeLexerConstants.ESCAPE) ;an escaped character in the comment
            Position += 2 ;skip over the entire escape sequence (allows escaping of comment chars: /* Some `/* Comment */)
        Else If (CurrentTwoChar = CodeLexerConstants.MULTILINE_COMMENT_BEGIN) ;found a nested comment
            CommentLevel ++
        Else If (CurrentTwoChar = CodeLexerConstants.MULTILINE_COMMENT_END) ;found a closing comment
            CommentLevel --
        Position ++
    }
    Position += StrLen(CodeLexerConstants.MULTILINE_COMMENT_END) - 1 ;skip over the closing comment
}

;lexes a object access operator, which can be either a concatenation operator or an object access operator depending on the surrounding whitespace
CodeLexObjectAccessOperator(ByRef Code,ByRef Position,ByRef Tokens,ByRef Errors,FileIndex)
{ ;returns 1 on invalid operator usage, 0 otherwise
    global CodeTokenTypes, CodeLexerConstants
    Position ++, NextChar := SubStr(Code,Position,1) ;store the surrounding characters
    If InStr(CodeLexerConstants.IDENTIFIER,NextChar) ;object access (lexer handling ensures that Var.123.456 will have the purely numerical keys interpreted as identifiers instead of numbers)
    {
        Tokens.Insert(CodeTokenOperator(".",Position - 1,FileIndex)) ;add an object access token to the token array
        CodeLexIdentifier(Code,Position,Tokens,FileIndex) ;lex identifier
    }
    Else ;object access was not followed by an identifier
    {
        CodeRecordError(Errors,"INVALID_OBJECT_ACCESS",3,FileIndex,Position - 1,1,[Object("Position",Position,"Length",1)])
        Return, 1
    }
    Return, 0
}

;lexes operators and syntax elements
CodeLexSyntaxElement(ByRef Code,ByRef Position,ByRef Tokens,ByRef FileIndex)
{ ;returns 1 if no syntax element was found, 0 otherwise
    global CodeTokenTypes, CodeOperatorTable, CodeLexerConstants, CodeLexerOperatorMaxLength
    Temp1 := CodeLexerOperatorMaxLength, Position1 := Position
    Loop, %CodeLexerOperatorMaxLength% ;loop until a valid token is found
    {
        SyntaxElement := SubStr(Code,Position,Temp1)
        If (SyntaxElement = CodeLexerConstants.SEPARATOR) ;found separator
            Tokens.Insert(CodeTokenSeparator(Position1,FileIndex)) ;add separator to the token array
        Else If ((ObjHasKey(CodeOperatorTable.NullDenotation,SyntaxElement) || ObjHasKey(CodeOperatorTable.LeftDenotation,SyntaxElement)) ;found operator in null or left denotation of the operator table
                && !(InStr(CodeLexerConstants.IDENTIFIER,SubStr(SyntaxElement,0)) ;last character of the operator is an identifier character
                && (CurrentChar := SubStr(Code,Position + Temp1,1)) != "" ;operator is not at the end of the source file
                && InStr(CodeLexerConstants.IDENTIFIER,CurrentChar))) ;character after the operator is an identifier character
            Tokens.Insert(CodeTokenOperator(SyntaxElement,Position1,FileIndex)) ;add the operator to the token array
        Else
        {
            Temp1 -- ;reduce the length of the input to be checked
            Continue
        }
        Position += StrLen(SyntaxElement) ;move past the syntax element, making sure the position is not past the end of the file
        Return, 0
    }
    Return, 1 ;not a syntax element
}

;lexes a number, and if it is not a valid number, notify that it may be an identifier
CodeLexNumber(ByRef Code,ByRef Position,ByRef Tokens,FileIndex)
{ ;returns 1 if the input could not be lexed as a number, 0 otherwise
    global CodeTokenTypes, CodeLexerConstants
    Output := "", Position1 := Position, NumberChars := "1234567890", DecimalUsed := 0
    If (SubStr(Code,Position,2) = "0x") ;hexadecimal number
        DecimalUsed := 1, Position += 2, Output .= "0x", NumberChars .= "abcdefABCDEF" ;prevent the usage of decimals in hexadecimal numbers, skip over the identifying characters, append them to the number, and expand the valid number characters set
    Loop
    {
        CurrentChar := SubStr(Code,Position,1)
        If (CurrentChar = "") ;past end of string
            Break
        If InStr(NumberChars,CurrentChar) ;is a valid number character
            Output .= CurrentChar
        Else If (CurrentChar = ".") ;is a decimal point
        {
            If DecimalUsed ;input already had a decimal point, so is an identifier
            {
                Position := Position1 ;return the position back to the start of this section, to try to process it again as an identifier
                Return, 1
            }
            Output .= CurrentChar, DecimalUsed := 1 ;set a flag to show that a decimal point has been used
        }
        Else If InStr(CodeLexerConstants.IDENTIFIER,CurrentChar) ;notify if the code is a valid identifier char if it cannot be processed as a number
        {
            Position := Position1 ;return the position back to the start of this section, to try to parse it again as an identifier
            Return, 1
        }
        Else ;end of number
            Break
        Position ++
    }
    Tokens.Insert(CodeTokenNumber(Output,Position1,FileIndex)) ;add the number literal to the token array
    Return, 0
}

;lexes an identifier
CodeLexIdentifier(ByRef Code,ByRef Position,ByRef Tokens,ByRef FileIndex)
{
    global CodeTokenTypes, CodeLexerConstants
    Output := SubStr(Code,Position,1), Position1 := Position, Position ++
    Loop
    {
        CurrentChar := SubStr(Code,Position,1)
        If (CurrentChar = "" || !InStr(CodeLexerConstants.IDENTIFIER,CurrentChar)) ;past end of string, or found a character that was not part of the identifier
            Break
        Output .= CurrentChar, Position ++
    }
    Tokens.Insert(CodeTokenIdentifier(Output,Position1,FileIndex)) ;add the identifier to the token array
}