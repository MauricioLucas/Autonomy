#NoEnv

#Include Code.ahk

/*
Copyright 2011 Anthony Zhang <azhang9@gmail.com>

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

/*
Possible Simplifications
------------------------

Resources:

* http://en.wikipedia.org/wiki/Category:Compiler_optimizations
* http://en.wikipedia.org/wiki/Compiler_optimization
* http://en.wikipedia.org/wiki/Constant_folding

Simplifications:

* constant folding:                                  (3 + 4) * Sin(5) -> [Value of (3 + 4) * Sin(5)]
* common subexpression elimination:                  http://en.wikipedia.org/wiki/Common_subexpression_elimination
* integer bit shift left equivalance:                Integer1 * [Power of 2: Integer2] -> Integer1 << [Log2(Integer2)]
* integer bit shift right equivalance:               Integer1 // [Power of 2: Integer2] -> Integer1 >> [Log2(Integer2)]
* floor divide:                                      Floor(Number1 / Number2) -> Number1 // Number2
* multiply by one:                                   [Evaluates to integer 1] * Number, Number * [Evaluates to integer 1] -> Number
* divide by one:                                     Integer / [Evaluates to 1] -> Integer
* zero product property:                             Number * [Evaluates to 0] -> 0 ;if the multiplicand that evaluates to zero was a float, then the number type should be converted to a float as well
* bitwise modulo:                                    Mod(Integer1,[Power of 2: Integer2]) -> Integer1 & [Integer2 - 1]
* logical transforms:                                (!Something && !SomethingElse) -> !(Something || SomethingElse) ;many other different types of logical transforms too
* type specialization:                               If [Something that evaluates to a boolean: Expression] -> If Expression = True ;avoids needing to check both boolean truthiness and for string truthiness
* case sensitivity:                                  If [String: String1] = [String without alphabetic characters: String2] -> If String [Case sensitive compare] ;avoid case insensitivity routines that may be more complex or slow
* static single assignment                           http://en.wikipedia.org/wiki/Static_single_assignment_form
* strength reduction:                                http://en.wikipedia.org/wiki/Strength_reduction
* partial redundancy elimination:                    http://en.wikipedia.org/wiki/Partial_redundancy_elimination
* scalar replacement:                                http://kitty.2y.cc/doc/intel_cc_80/doc/c_ug/lin1074.htm
*/

;/*
#Include Resources\Reconstruct.ahk
#Include Lexer.ahk
#Include Parser.ahk

SetBatchLines, -1

Code = 
(
1+2*3
)

If CodeInit()
{
 Display("Error initializing code tools.`n") ;display error at standard output
 ExitApp ;fatal error
}

FileName := A_ScriptFullPath
CodeSetScript(FileName,Errors,Files) ;set the current script file

CodeLexInit()
CodeLex(Code,Tokens,Errors)

CodeParseInit()
Result := CodeParse(Tokens,SyntaxTree,Errors)

MsgBox % Clipboard := CodeReconstructShowSyntaxTree(CodeSimplify(SyntaxTree))
ExitApp
*/

;simplifies a syntax tree given as input
CodeSimplify(SyntaxTree)
{
 global CodeTreeTypes
 static SimplifyOperations := Object("ADD",Func("CodeSimplifyAdd"),"INVERT",Func("CodeSimplifyInvert"))
 NodeType := SyntaxTree[1]
 If (NodeType = CodeTreeTypes.OPERATION)
 {
  Operation := SyntaxTree[2][2] ;wip: support dynamic operations
  If !ObjHasKey(SimplifyOperations,Operation)
   Return, SyntaxTree

  Index := 3, Applyable := 1 ;wip: use recursive applyable measure
  Loop, % ObjMaxIndex(SyntaxTree) - 2
  {
   Node := SyntaxTree[Index]
   If (Node[1] != CodeTreeTypes.NUMBER && Node[1] != CodeTreeTypes.STRING)
   {
    Applyable := 0
    Break
   }
   Index ++
  }

  If Applyable
   Return, SimplifyOperations[Operation](SyntaxTree)
  Else
   Return, SyntaxTree
 }
 Return, SyntaxTree
}

CodeSImplifyAdd(This,Node)
{
 global CodeTreeTypes
 Return, [CodeTreeTypes.NUMBER,Node[3][2] + Node[4][2],0,0] ;create an number tree node
}

CodeSimplifyInvert(This)
{
 
}