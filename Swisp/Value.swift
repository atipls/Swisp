//
//  Value.swift
//  Swisp
//
//  Created by Hajdu Attila on 2021. 09. 11..
//

import Foundation

let TYPE_NONE   = 0
let TYPE_ERROR  = 1
let TYPE_NUMBER = 2
let TYPE_SYMBOL = 3
let TYPE_STRING = 4
let TYPE_LAMBDA = 5
let TYPE_SEXPR  = 6
let TYPE_QEXPR  = 7

class Value: Equatable {
    var type: Int = TYPE_NONE
    
    var error: String = ""
    var number: Int64 = 0
    var symbol: String = ""
    var string: String = ""
    
    var builtin: ((Environment, Value) -> Value)?
    var environment: Environment?
    var formals: Value?
    var body: Value?
    
    var cells: [Value]?
    
    var count: Int {
        return cells!.count
    }
    
    static func Error(_ error: String) -> Value {
        let value = Value()
        value.type = TYPE_ERROR
        value.error = error
        return value
    }
    
    static func Number(_ number: Int64) -> Value {
        let value = Value()
        value.type = TYPE_NUMBER
        value.number = number
        return value
    }
    
    static func Symbol(_ symbol: String) -> Value {
        let value = Value()
        value.type = TYPE_SYMBOL
        value.symbol = symbol
        return value
    }
    
    static func String(_ string: String) -> Value {
        let value = Value()
        value.type = TYPE_STRING
        value.string = string
        return value
    }
    
    static func Builtin(_ builtin: @escaping (Environment, Value) -> Value) -> Value {
        let value = Value()
        value.type = TYPE_LAMBDA
        value.builtin = builtin
        return value
    }
    
    static func Lambda(_ environment: Environment, _ formals: Value, _ body: Value) -> Value {
        let value = Value()
        value.type = TYPE_LAMBDA
        value.environment = environment
        value.formals = formals
        value.body = body
        return value
    }
    
    static func SExpr() -> Value {
        let value = Value()
        value.type = TYPE_SEXPR
        value.cells = []
        return value
    }

    static func QExpr() -> Value {
        let value = Value()
        value.type = TYPE_QEXPR
        value.cells = []
        return value
    }
    
    func copy() -> Value {
        let value = Value()
        
        value.type = type
        switch type {
        case TYPE_ERROR:  value.error  = error
        case TYPE_NUMBER: value.number = number
        case TYPE_SYMBOL: value.symbol = symbol
        case TYPE_STRING: value.string = string
        case TYPE_LAMBDA:
            if let builtin = builtin {
                value.builtin = builtin
            } else {
                value.environment = environment?.copy()
                value.formals = formals
                value.body = body
            }
        case TYPE_SEXPR: fallthrough
        case TYPE_QEXPR:
            value.cells = []
            for cell in cells! {
                value.cells!.append(cell.copy())
            }
        default: break
        }
        
        return value
    }
    
    func add(_ value: Value) -> Value {
        cells?.append(value)
        return self
    }
    
    func join(_ value: Value) -> Value {
        for cell in value.cells! {
            _ = add(cell)
        }
        return self
    }
    
    func pop(_ index: Int) -> Value {
        let value = cells![index]
        cells!.remove(at: index)
        return value
    }
    
    private let escapable = "\n\r\t\\'\""
    private func escape(_ char: Character) -> String {
        switch char {
        case "\n": return "\\n";
        case "\r": return "\\r";
        case "\t": return "\\t";
        case "\\": return "\\\\";
        case "\'": return "\\\'";
        case "\"": return "\\\"";
        default: return ""
        }
    }
    
    private func describeExpression(_ open: Character, _ close: Character) -> String {
        var expression = "\(open)"
        for cell in cells! {
            expression.append(cell.description)
        }
        expression.append(close)
        return expression
    }
    
    private var describeString: String {
        var expression = "\""

        for char in string {
            if escapable.contains(char) {
                expression.append(escape(char))
            } else {
                expression.append(char)
            }
        }
        
        expression.append("\"")
        return expression
    }
    
    var description: String {
        switch type {
        case TYPE_ERROR:  return "Error: \(error)"
        case TYPE_NUMBER: return "\(number)"
        case TYPE_SYMBOL: return symbol
        case TYPE_STRING: return describeString
        case TYPE_LAMBDA:
            if builtin != nil {
                return "<builtin>"
            } else {
                return "(\\ \(formals!) \(body!))"
            }
        case TYPE_SEXPR: return describeExpression("(", ")")
        case TYPE_QEXPR: return describeExpression("{", "}")
        default: return ""
        }
    }
    
    static func typeName(of: Int) -> String {
        switch of {
        case TYPE_ERROR:  return "Error"
        case TYPE_NUMBER: return "Number"
        case TYPE_SYMBOL: return "Symbol"
        case TYPE_STRING: return "String"
        case TYPE_LAMBDA: return "Lambda"
        case TYPE_SEXPR:  return "S-Expr"
        case TYPE_QEXPR:  return "Q-Expr"
        default: return ""
        }
    }
    
    static func == (lhs: Value, rhs: Value) -> Bool {
        if lhs.type != rhs.type {
            return false
        }
        
        switch lhs.type {
        case TYPE_ERROR:  return lhs.error == rhs.error
        case TYPE_NUMBER: return lhs.number == rhs.number
        case TYPE_SYMBOL: return lhs.symbol == rhs.symbol
        case TYPE_STRING: return lhs.string == rhs.string
        case TYPE_LAMBDA:
            if lhs.builtin != nil || rhs.builtin != nil {
                return lhs.builtin.debugDescription == rhs.builtin.debugDescription
            } else {
                return lhs.formals == rhs.formals && lhs.body == rhs.body
            }
        case TYPE_SEXPR: fallthrough
        case TYPE_QEXPR:
            if lhs.cells!.count != rhs.cells!.count {
                return false
            }
            
            for (x, y) in zip(lhs.cells!, rhs.cells!) {
                if x != y {
                    return false
                }
            }
            
            return true
        default: return false
        }
    }

    /*
     lval* lval_take(lval* v, int i) {
       lval* x = lval_pop(v, i);
       lval_del(v);
       return x;
     }
     */
}
