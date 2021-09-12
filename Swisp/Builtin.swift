//
//  Builtin.swift
//  Swisp
//
//  Created by Hajdu Attila on 2021. 09. 11..
//

import Foundation

func isType(_ name: String, _ arguments: Value, _ index: Int, _ expected: Int) -> Value? {
    let value = arguments.cells![index]
    if value.type != expected {
        return Value.Error("Function '\(name)' passed incorrect type for argument \(index). Got \(Value.typeName(of: value.type)), expected \(Value.typeName(of: expected))")
    }
    return nil
}

func argumentCount(_ name: String, _ arguments: Value, _ expected: Int) -> Value? {
    if arguments.count != expected {
        return Value.Error("Function '\(name)' passed incorrect number of arguments. Got \(arguments.count), Expected \(expected).")
    }
    return nil
}

func notEmpty(_ name: String, _ arguments: Value, _ index: Int) -> Value? {
    if arguments.cells![index].count == 0 {
        return Value.Error("Function '\(name)' passed {} for argument \(index).")
    }
    return nil
}

func ensure(_ cond: Bool, _ message: String) -> Value? {
    if !cond {
        return Value.Error(message)
    }
    return nil
}

func builtinLambda(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("\\", arguments, 2) { return error }
    if let error = isType("\\", arguments, 0, TYPE_QEXPR) { return error }
    if let error = isType("\\", arguments, 1, TYPE_QEXPR) { return error }

    for cell in arguments.cells![0].cells! {
        if let error = ensure(cell.type == TYPE_SYMBOL,
                              "Cannot define a non-symbol. Got \(Value.typeName(of: cell.type))") {
            return error
        }
    }
    
    let formals = arguments.pop(0)
    let body = arguments.pop(0)

    return Value.Lambda(environment, formals, body)
}

func builtinList(_ environment: Environment, _ arguments: Value) -> Value {
    arguments.type = TYPE_QEXPR
    return arguments
}

func builtinHead(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("head", arguments, 1) { return error }
    if let error = isType("head", arguments, 0, TYPE_QEXPR) { return error }
    if let error = notEmpty("head", arguments, 0) { return error }

    let value = arguments.pop(0)
    while value.count > 1 {
        _ = value.pop(1)
    }
    return value
}

func builtinTail(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("tail", arguments, 1) { return error }
    if let error = isType("tail", arguments, 0, TYPE_QEXPR) { return error }
    if let error = notEmpty("tail", arguments, 0) { return error }

    let value = arguments.pop(0)
    _ = value.pop(0)
    return value
}

func builtinEval(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("eval", arguments, 1) { return error }
    if let error = isType("eval", arguments, 0, TYPE_QEXPR) { return error }
    
    let value = arguments.pop(0)
    value.type = TYPE_SEXPR
    return eval(environment, value)
}

func builtinJoin(_ environment: Environment, _ arguments: Value) -> Value {
    for index in 0..<arguments.count {
        if let error = isType("join", arguments, index, TYPE_QEXPR) {
            return error
        }
    }
    
    let value = arguments.pop(0)
    while arguments.count > 0 {
        _ = value.add(arguments.pop(0))
    }
    return value
}

func builtinOp(_ environment: Environment, _ arguments: Value, _ op: String) -> Value {
    for index in 0..<arguments.count {
        if let error = isType(op, arguments, index, TYPE_QEXPR) {
            return error
        }
    }
    
    var value = arguments.pop(0)
    
    if op == "-" && arguments.count == 0 {
        value.number = -value.number
    }
    
    while arguments.count > 0 {
        let operand = arguments.pop(0)
        switch op {
        case "+": value.number += operand.number
        case "-": value.number -= operand.number
        case "*": value.number *= operand.number
        case "/":
            if operand.number == 0 {
                value = Value.Error("Division by zero")
                break
            }
            value.number /= operand.number
        default: continue
        }
    }
    
    return value
}

func builtinAdd(_ environment: Environment, _ arguments: Value) -> Value { return builtinOp(environment, arguments, "+") }
func builtinSub(_ environment: Environment, _ arguments: Value) -> Value { return builtinOp(environment, arguments, "-") }
func builtinMul(_ environment: Environment, _ arguments: Value) -> Value { return builtinOp(environment, arguments, "*") }
func builtinDiv(_ environment: Environment, _ arguments: Value) -> Value { return builtinOp(environment, arguments, "/") }

func builtinVar(_ environment: Environment, _ arguments: Value, _ fun: String) -> Value {
    if let error = isType(fun, arguments, 0, TYPE_QEXPR) { return error }

    let cells = arguments.cells![0].cells!
    for cell in cells {
        if let error = ensure(cell.type == TYPE_SYMBOL,
            "'\(fun)' cannot define a non-symbol. Got \(Value.typeName(of: cell.type))") {
            return error
        }
    }

    let symbols = arguments.cells![0]
    if let error = ensure(symbols.count == arguments.count - 1,
            "'\(fun)' was passed with too many arguments. Wanted \(symbols.count), got \(arguments.count - 1)") {
        return error
    }
 
    for index in 0..<symbols.count {
        if fun == "def" { environment.def(symbols.cells![index], arguments.cells![index + 1]) }
        if fun == "="   { environment.put(symbols.cells![index], arguments.cells![index + 1]) }
    }
    
    return Value.SExpr()
}

func builtinDef(_ environment: Environment, _ arguments: Value) -> Value { return builtinVar(environment, arguments, "def") }
func builtinPut(_ environment: Environment, _ arguments: Value) -> Value { return builtinVar(environment, arguments, "=") }

func builtinOrd(_ environment: Environment, _ arguments: Value, _ op: String) -> Value {
    if let error = argumentCount(op, arguments, 2) { return error }
    if let error = isType(op, arguments, 0, TYPE_NUMBER) { return error }
    if let error = isType(op, arguments, 1, TYPE_NUMBER) { return error }

    var result: Bool = false
    if op == ">" { result = arguments.cells![0].number > arguments.cells![1].number }
    if op == "<" { result = arguments.cells![0].number < arguments.cells![1].number }
    if op == ">=" { result = arguments.cells![0].number >= arguments.cells![1].number }
    if op == "<=" { result = arguments.cells![0].number <= arguments.cells![1].number }

    return Value.Number(result ? 1 : 0)
}

func builtinGt(_ environment: Environment, _ arguments: Value) -> Value { return builtinOrd(environment, arguments, ">") }
func builtinLt(_ environment: Environment, _ arguments: Value) -> Value { return builtinOrd(environment, arguments, "<") }
func builtinGe(_ environment: Environment, _ arguments: Value) -> Value { return builtinOrd(environment, arguments, ">=") }
func builtinLe(_ environment: Environment, _ arguments: Value) -> Value { return builtinOrd(environment, arguments, "<=") }

func builtinCmp(_ environment: Environment, _ arguments: Value, _ op: String) -> Value {
    if let error = argumentCount(op, arguments, 2) { return error }

    var result: Bool = false
    if op == "==" { result = arguments.cells![0] == arguments.cells![1] }
    if op == "!=" { result = arguments.cells![0] != arguments.cells![1] }
    
    return Value.Number(result ? 1 : 0)
}

func builtinEq(_ environment: Environment, _ arguments: Value) -> Value { return builtinCmp(environment, arguments, "==") }
func builtinNe(_ environment: Environment, _ arguments: Value) -> Value { return builtinCmp(environment, arguments, "!=") }

func builtinIf(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("if", arguments, 3) { return error }
    if let error = isType("if", arguments, 0, TYPE_NUMBER) { return error }
    if let error = isType("if", arguments, 1, TYPE_QEXPR) { return error }
    if let error = isType("if", arguments, 2, TYPE_QEXPR) { return error }
    
    arguments.cells![1].type = TYPE_SEXPR
    arguments.cells![2].type = TYPE_SEXPR
    
    if arguments.cells![0].number != 0 {
        return eval(environment, arguments.pop(1))
    } else {
        return eval(environment, arguments.pop(2))
    }
}

func builtinLoad(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("load", arguments, 1) { return error }
    if let error = isType("load", arguments, 0, TYPE_STRING) { return error }

    do {
        let input = try String(contentsOfFile: arguments.cells![0].string)
        
        var index = 0
        let expression = readExpression(Array(input), &index, "\0")

        if expression.type != TYPE_ERROR {
            while expression.count > 0 {
                let result = eval(environment, expression.pop(0))
                if result.type == TYPE_ERROR {
                    print(result.description)
                }
            }
        } else { print(expression.description) }
        
        return Value.SExpr()
    } catch { return Value.Error("Could not load library \(arguments.cells![0].string)") }
}

func builtinPrint(_ environment: Environment, _ arguments: Value) -> Value {
    for cell in arguments.cells! {
        print("\(cell.description) ", terminator: "")
    }
    print("")
    
    return Value.SExpr()
}

func builtinError(_ environment: Environment, _ arguments: Value) -> Value {
    if let error = argumentCount("error", arguments, 1) { return error }
    if let error = isType("error", arguments, 0, TYPE_STRING) { return error }

    return Value.Error(arguments.cells![0].string)
}
