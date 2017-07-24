mutable struct Variable
    id
    t
    val
end
mutable struct EXPR{T}
    args::Vector
    span::Int
    defs::Vector{Variable}
    val::String
end

abstract type IDENTIFIER end
abstract type LITERAL{K} end
abstract type KEYWORD{K} end
abstract type OPERATOR{P,K,dot} end
abstract type PUNCTUATION{K} end
abstract type HEAD{K} end
abstract type ERROR end



function LITERAL(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    if ps.t.kind == Tokens.STRING || ps.t.kind == Tokens.TRIPLE_STRING ||
       ps.t.kind == Tokens.CMD || ps.t.kind == Tokens.TRIPLE_CMD
        return parse_string_or_cmd(ps)
    else
        EXPR{LITERAL{ps.t.kind}}(EXPR[], span, Variable[], ps.t.val)
    end
end

IDENTIFIER(ps::ParseState) = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], ps.t.val)

OPERATOR(ps::ParseState) = EXPR{OPERATOR{precedence(ps.t),ps.t.kind,ps.dot}}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "")

KEYWORD(ps::ParseState) = EXPR{KEYWORD{ps.t.kind}}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "")

PUNCTUATION(ps::ParseState) = EXPR{PUNCTUATION{ps.t.kind}}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "")

function INSTANCE(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    ps.errored && return EXPR{ERROR}(EXPR[], span, Variable[], "")
    if ps.t.kind == Tokens.ENDMARKER
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedInputEnd}(ps.t.startbyte + (0:0), [], "Unexpected end of input"))
        return EXPR{ERROR}(EXPR[], span, Variable[], "Unexpected end of input")
    end
    return isidentifier(ps.t) ? IDENTIFIER(ps) : 
        isliteral(ps.t) ? LITERAL(ps) :
        iskw(ps.t) ? KEYWORD(ps) :
        isoperator(ps.t) ? OPERATOR(ps) :
        ispunctuation(ps.t) ? PUNCTUATION(ps) :
        ps.t.kind == Tokens.SEMICOLON ? PUNCTUATION(ps) :
        (ps.errored = true; EXPR{ERROR}(EXPR[], span, Variable[], ""))
end




# heads


const TRUE = EXPR{LITERAL{Tokens.TRUE}}(EXPR[], 0, Variable[], "")
const FALSE = EXPR{LITERAL{Tokens.FALSE}}(EXPR[], 0, Variable[], "")
const NOTHING = EXPR{HEAD{:nothing}}(EXPR[], 0, Variable[], "nothing")
const GlobalRefDOC = EXPR{HEAD{:globalrefdoc}}(EXPR[], 0, Variable[], "globalrefdoc")



abstract type Scope{t} end

mutable struct File
    imports
    includes::Vector{Tuple{String,Any}}
    path::String
    ast::EXPR
    errors
end
File(path::String) = File([], [], path, EXPR{FileH}(EXPR[], 0, Variable[], ""), [])

mutable struct Project
    path::String
    files::Vector{File}
end



const NoVariable = Variable(NOTHING, NOTHING, NOTHING)

abstract type Head end

abstract type Call <: Head end
abstract type UnaryOpCall <: Head end
abstract type UnarySyntaxOpCall <: Head end
abstract type BinaryOpCall <: Head end
abstract type BinarySyntaxOpCall <: Head end
abstract type ConditionalOpCall <: Head end
abstract type ComparisonOpCall <: Head end
abstract type ChainOpCall <: Head end
abstract type ColonOpCall <: Head end

abstract type Abstract <: Head end
abstract type Begin <: Head end
abstract type Bitstype <: Head end
abstract type Block <: Head end
abstract type Break <: Head end
abstract type Cell1d <: Head end
abstract type Const <: Head end
abstract type Continue <: Head end
abstract type Comparison <: Head end
abstract type Curly <: Head end
abstract type Do <: Head end
abstract type Filter <: Head end
abstract type Flatten <: Head end
abstract type For <: Head end
abstract type FunctionDef <: Head end
abstract type Generator <: Head end
abstract type Global <: Head end
abstract type If <: Head end
abstract type Kw <: Head end
abstract type Let <: Head end
abstract type Local <: Head end
abstract type Macro <: Head end
abstract type MacroCall <: Head end
abstract type Mutable <: Head end
abstract type Parameters <: Head end
abstract type Primitive <: Head end
abstract type Quote <: Head end
abstract type Quotenode <: Head end
abstract type InvisBrackets <: Head end
abstract type StringH <: Head end
abstract type Struct <: Head end
abstract type Try <: Head end
abstract type TupleH <: Head end
abstract type TypeAlias <: Head end
abstract type FileH <: Head end
abstract type Return <: Head end
abstract type Vect <: Head end
abstract type While <: Head end
abstract type x_Cmd <: Head end
abstract type x_Str <: Head end

abstract type ModuleH <: Head end
abstract type BareModule <: Head end
abstract type TopLevel <: Head end
abstract type Export <: Head end
abstract type Import <: Head end
abstract type ImportAll <: Head end
abstract type Using <: Head end

abstract type Comprehension <: Head end
abstract type DictComprehension <: Head end
abstract type TypedComprehension <: Head end
abstract type Hcat <: Head end
abstract type TypedHcat <: Head end
abstract type Ref <: Head end
abstract type Row <: Head end
abstract type Vcat <: Head end
abstract type TypedVcat <: Head end
abstract type Vect <: Head end

Quotenode(x::EXPR) = EXPR{Quotenode}(EXPR[x], x.span, Variable[], "")
