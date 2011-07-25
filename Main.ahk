#NoEnv

#Warn All

SetBatchLines(-1)

#Include Resources\Functions.ahk
#Include Resources\Get Error.ahk
#Include Resources\Reconstruct.ahk

#Include Code.ahk
#Include Lexer.ahk
#Include Preprocessor.ahk
#Include Parser.ahk

/*
TODO
----

* preprocessor macros with #Define Enum.Property := 0x4A
* Support a command syntax, that is translated to a function call on load (dotted notation only - no square brackets support). Detect this form by making sure the token is immediately after a block brace, opening square bracket, opening parenthesis, or line end, and the token after the function is either a literal, an identifier, a separator, an operator that doesn't take a parameter on its left, a block brace, or a line end: Math.Mod, 100, 5
* Make syntax tree types an enumeration
* Read mk:@MSITStore:C:\Program%20Files\AutoHotkey\AutoHotkey_L\AutoHotkey_L.chm::/docs/misc/Performance.htm
* Rewrite parser with TDOP/Pratt/Precedence Climbing parsing algorithm. Remove operator table if not needed afterwards
* Script that converts AutoHotkey code to AHK Code Tools

* Add constant defining capability that complements macros by obeying scope - used like this (needs value substitution optimisation if value is an object and there is no []-type access): Constant Something := 10
* After the command syntax is implemented, remove the STATEMENT token type (as the parser can now detect statements, fixing currently broken cases like the assignment "Else := Variable"), and change it to the DIRECTIVE token type, for preprocessor directives only
* Scope info should be attached to each variable
* Incremental parser and lexer for IDE use, have object mapping line numbers to token indexes, have parser save state at intervals, lex changed lines only, restore parser state to the saved state right before the token index of the changed token, keep parsing to the end of the file
* Lua-like _G[] mechanism to replace dynamic variables. Afterwards remove dynamic variable functionality and make % the modulo or format string operator
* "local" keyword works on current block, instead of current function, and can make block assume-local: If Something { local SomeVar := "Test" } ;SomeVar is freed after the If block goes out of scope
* Function definitions are variables holding function references (implemented as function pointers, and utilising reference counting), so variables and functions are in the same namespace
* Make implementation self hosting and change the code to conform to the syntax
* Static tail call detection
* Distinct Array type using contingous memory, faster than Object hash table implementation
*/

FileName := A_ScriptFullPath ;set the file name of the current file

Code = 
(
Var := Something
Return, 1 + 1
)

;Code := "a + !b * (1 + 3)"

If CodeInit()
{
 Display("Error initializing code tools.`n") ;display error at standard output
 ExitApp(1) ;fatal error
}

CodeSetScript(FileName,Errors,Files) ;set the current script file

CodeLexInit()
CodeLex(Code,Tokens,Errors)
;DisplayObject(Tokens)

CodePreprocessInit(Files)
CodePreprocess(Tokens,ProcessedTokens,Errors,Files)
DisplayObject(ProcessedTokens)
DisplayObject(Errors)

CodeParse(ProcessedTokens,SyntaxTree,Errors)
;DisplayObject(SyntaxTree)

If (ObjMaxIndex(Errors) != "")
 Display(CodeGetError(Code,Errors,Files)) ;display error at standard output

;DisplayObject(SyntaxTree)
;MsgBox % CodeRecontructSyntaxTree(SyntaxTree)

ExitApp()