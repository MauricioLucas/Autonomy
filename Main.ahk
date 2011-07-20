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

* Have all code be stored in CodeFiles, to make it simpler for error handler to access it
* Rewrite parser to not use shunting yard algorithm anymore, it's becoming a big, hackish mess. Look into TDOP/Pratt parser instead. This will also remove the need for the operator table
* Support a command syntax, that is translated to a function call on load (dotted notation only - no square brackets support): Math.Mod, 100, 5

* Scope info should be attached to each variable
* Incremental parser and lexer for IDE use, have object mapping line numbers to token indexes, have parser save state at intervals, lex changed lines only, restore parser state to the saved state right before the token index of the changed token, keep parsing to the end of the file
* Lua-like _G[] mechanism to replace dynamic variables. Afterwards remove dynamic variable functionality and make % the modulo operator
* "local" keyword works on current block, instead of current function, and can make block assume-local: If Something { local SomeVar := "Test" } ;SomeVar is freed after the If block goes out of scope
* Function definitions are variables holding function references (implemented as function pointers, and utilising reference counting), so variables and functions are in the same namespace
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

CodeSetScript(FileName,Code,Errors) ;set the current script file

CodeLexInit()
CodeLex(Code,Tokens,Errors)
;DisplayObject(Tokens)

CodePreprocessInit()
CodePreprocess(Tokens,ProcessedTokens,Errors)
DisplayObject(ProcessedTokens)
DisplayObject(Errors)

CodeParse(ProcessedTokens,SyntaxTree,Errors)
;DisplayObject(SyntaxTree)

If (ObjMaxIndex(Errors) <> "")
 Display(CodeGetError(Code,Errors)) ;display error at standard output

;DisplayObject(SyntaxTree)
;MsgBox % CodeRecontructSyntaxTree(SyntaxTree)

ExitApp()