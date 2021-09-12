//
//  main.swift
//  Swisp
//
//  Created by Hajdu Attila on 2021. 09. 11..
//

import Foundation

class Environment {
    var parent: Environment?
    var values: [String: Value] = [:]

    func copy() -> Environment {
        let environment = Environment()
        environment.parent = parent
        for value in values {
            environment.values[value.key] = value.value.copy()
        }
        return environment
    }
    
    
    func get(_ key: Value) -> Value {
        if let value = values[key.symbol] {
            return value
        } else if let parent = parent {
            return parent.get(key)
        }
        return Value.Error("Unbound symbol \(key.symbol)")
    }
    
    func put(_ key: Value, _ value: Value) {
        values[key.symbol] = value.copy()
    }
    
    func def(_ key: Value, _ value: Value) {
        var target = self
        while target.parent != nil {
            target = target.parent!
        }
        target.put(key, value)
    }
    
    func addBuiltin(_ name: String, _ builtin: @escaping (Environment, Value) -> Value) {
        put(Value.Symbol(name), Value.Builtin(builtin))
    }
}

func callValue(_ environment: Environment, _ function: Value, _ arguments: Value) -> Value {
    if let builtin = function.builtin {
        return builtin(environment, arguments)
    }
    
    let given = arguments.count
    let total = function.formals!.count

    while arguments.count > 0 {
        if function.formals!.count == 0 {
            return Value.Error("Function passed too many arguments. Got \(given), expected \(total)")
        }
        
        let symbol = function.formals!.pop(0)
        if symbol.symbol == "&" {
            if function.formals!.count != 1 {
                return Value.Error("Function format invalid. Symbol '&' not followed by single symbol.")
            }

            let newsym = function.formals!.pop(0)
            function.environment!.put(newsym, builtinList(environment, arguments))
            break
        }
        
        let value = arguments.pop(0)
        environment.put(symbol, value)
    }

    if function.formals!.count > 0
        && function.formals!.cells![0].symbol == "&" {
        
        if function.formals!.count != 2 {
            return Value.Error("Function format invalid. Symbol '&' not followed by single symbol.")
        }
        
        _ = function.formals!.pop(0)
        
        let symbol = function.formals!.pop(0)
        let value = Value.QExpr()
        
        function.environment!.put(symbol, value)
    }
    
    if function.formals!.count == 0 {
        function.environment!.parent = environment
        return builtinEval(function.environment!, Value.SExpr().add(function.body!))
    } else {
        return function.copy()
    }
}

func evalSExpr(_ environment: Environment, _ value: Value) -> Value {
    for index in 0..<value.count {
        value.cells![index] = eval(environment, value.cells![index])
    }

    for index in 0..<value.count {
        if value.cells![index].type == TYPE_ERROR {
            return value.pop(index)
        }
    }
    
    if value.count == 0 {
        return value
    } else if value.count == 1 {
        return eval(environment, value.pop(0))
    }
    
    let function = value.pop(0)
    if function.type != TYPE_LAMBDA {
        return Value.Error("S-Expression starts with incorrect type. Got \(Value.typeName(of: function.type)), expected Lambda")
    }
    
    return callValue(environment, function, value)
}

func eval(_ environment: Environment, _ value: Value) -> Value {
    switch value.type {
    case TYPE_SYMBOL: return environment.get(value)
    case TYPE_SEXPR:  return evalSExpr(environment, value)
    default: return value
    }
}

let validIdentifiers = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-*\\/=<>!&"
let validNumbers = "-0123456789"

func readSymbol(_ input: [Character], _ index: inout Int) -> Value {
    var symbol = ""
    while index < input.count && validIdentifiers.contains(input[index]) {
        symbol.append(input[index])
        index += 1
    }
    
    var isNumber = "-0123456789".contains(symbol.first!)
    for char in symbol.dropFirst() {
        if !validNumbers.contains(char) {
            isNumber = false
            break
        }
    }
    if symbol.count == 1 && symbol.first! == "-" {
        isNumber = false
    }
    
    if isNumber {
        let value = Int64.init(symbol)
        return value != nil ? Value.Number(value!) : Value.Error("Invalid number \(symbol)")
    } else {
        return Value.Symbol(symbol)
    }
}


private func unescape(_ char: Character) -> Character {
    switch char {
    case "n":  return "\n";
    case "r":  return "\r";
    case "t":  return "\t";
    case "\\": return "\\";
    case "\"": return "\"";
    case "'": return "'";
    default: return "\0";
    }
}

func readString(_ input: [Character], _ index: inout Int) -> Value {
    var string = ""
    index += 1
    while index < input.count && input[index] != "\"" {
        var char = input[index]
        if char == "\\" {
            index += 1
            
            let toEscape = input[index]
            if "nrt\\'\"".contains(toEscape) {
                char = unescape(toEscape)
            } else {
                return Value.Error("Invalid escape sequence \\\(toEscape)")
            }
        }
        
        string.append(char)
        index += 1
    }
    if index >= input.count {
        return Value.Error("Unexpected end of input")
    }
    
    index += 1
    return Value.String(string)
}

func readExpression(_ input: [Character], _ index: inout Int, _ end: Character) -> Value {
    let value = end == "}" ? Value.QExpr() : Value.SExpr()
    
    while index < input.count && input[index] != end {
        let sub = read(input, &index)
        if sub.type == TYPE_ERROR {
            return sub
        } else {
            _ = value.add(sub)
        }
    }
    
    index += 1
    return value
}

func skipWhitespace(_ input: [Character], _ index: inout Int) {
    while index < input.count && " \t\r\n\n\r;".contains(input[index]) {
        if input[index] == ";" {
            while index < input.count && input[index] != "\n" {
                index += 1
            }
        }
        
        index += 1
    }
}

func read(_ input: [Character], _ index: inout Int) -> Value {
    skipWhitespace(input, &index)
    
    var value: Value
    if index == input.count {
        return Value.Error("Unexpected end of input")
    }
    
    if input[index] == "(" {
        index += 1
        value = readExpression(input, &index, ")")
    } else if input[index] == "{" {
        index += 1
        value = readExpression(input, &index, "}")
    } else if validIdentifiers.contains(input[index]) {
        value = readSymbol(input, &index)
    } else if input[index] == "\"" {
        value = readString(input, &index)
    } else {
        value = Value.Error("Unexpected character \(input[index]) at index \(index)")
    }

    skipWhitespace(input, &index)
    return value
}

let environment = Environment()

environment.addBuiltin("+", { env, args in
    let x = args.pop(0)
    let y = args.pop(0)
    
    return Value.Number(x.number + y.number)
})

environment.addBuiltin("\\",  builtinLambda);
environment.addBuiltin("def", builtinDef);
environment.addBuiltin("=",   builtinPut);
environment.addBuiltin("list", builtinList);
environment.addBuiltin("head", builtinHead);
environment.addBuiltin("tail", builtinTail);
environment.addBuiltin("eval", builtinEval);
environment.addBuiltin("join", builtinJoin);
environment.addBuiltin("+", builtinAdd);
environment.addBuiltin("-", builtinSub);
environment.addBuiltin("*", builtinMul);
environment.addBuiltin("/", builtinDiv);
environment.addBuiltin("if", builtinIf);
environment.addBuiltin("==", builtinEq);
environment.addBuiltin("!=", builtinNe);
environment.addBuiltin(">",  builtinGt);
environment.addBuiltin("<",  builtinLt);
environment.addBuiltin(">=", builtinGe);
environment.addBuiltin("<=", builtinLe);
environment.addBuiltin("load",  builtinLoad);
environment.addBuiltin("error", builtinError);
environment.addBuiltin("print", builtinPrint);

while true {
    print("shell> ", terminator: "")
    
    if let line = readLine() {
        var index = 0
        let expression = readExpression(Array(line), &index, "\0")

        let result = eval(environment, expression)
        print(result.description)
    }
}
