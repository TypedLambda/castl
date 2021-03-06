--[[
    Copyright (c) 2014, Paul Bernier
    
    CASTL is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    CASTL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License
    along with CASTL. If not, see <http://www.gnu.org/licenses/>.
--]]

-- [[ CASTL JS core objects submodule]] --

local internal = require("castl.internal")
local objectProto = require("castl.prototype.object")
local functionProto = require("castl.prototype.function")
local arrayProto = require("castl.prototype.array")
local booleanProto = require("castl.prototype.boolean")
local numberProto = require("castl.prototype.number")
local stringProto = require("castl.prototype.string")
local dateProto = require("castl.prototype.date")
local errorProto = require("castl.prototype.error.error")
local rangeErrorProto = require("castl.prototype.error.range_error")
local referenceErrorProto = require("castl.prototype.error.reference_error")
local syntaxErrorProto = require("castl.prototype.error.syntax_error")
local typeErrorProto = require("castl.prototype.error.type_error")
local regexpProto = require("castl.prototype.regexp")
local errorHelper = require("castl.modules.error_helper")

local typeof = require("castl.jssupport").typeof

local RegExp

local coreObjects = {}
-- Dependencies
local getmetatable, setmetatable, rawget, rawset = getmetatable, setmetatable, rawget, rawset
local debug = debug
local type, max, strlen, strsub, tonumber= type, math.max, string.len, string.sub, tonumber
local pack, tinsert, concat, sort = table.pack, table.insert, table.concat, table.sort
local pairs, ipairs, tostring = pairs, ipairs, tostring
local require, error = require, error
local getPrototype, get, put, null  = internal.prototype, internal.get, internal.put, internal.null
local defaultValueNumber, setNewMetatable, toNumber = internal.defaultValueNumber, internal.setNewMetatable, internal.toNumber

_ENV = nil

-- Core objects metatables
local objectMt, arrayMt = {}, {}
local booleanMt, numberMt, stringMt = {}, {}, {}
local functionMt, undefinedMt = {}, {}

-- Hidden field _prototype keep reference to inherited table
objectMt._prototype = objectProto
functionMt._prototype = functionProto
arrayMt._prototype = arrayProto

coreObjects.objectToString = function(o)
    local ret = {"{ "}
    local elements = {}

    local props = coreObjects.props(o, false, false)
    for _, key in ipairs(props) do
        local k = key
        local v = o[key]

        if type(k) == "number" then
            k = "'" .. tostring(k) .. "'"
        else
            k = tostring(k)
        end

        if type(v) == "string" then
            v = "'" .. tostring(v) .. "'"
        else
            v = tostring(v)
        end

        tinsert(elements, k .. ": " .. v)
    end
    tinsert(ret, concat(elements, ", "))
    tinsert(ret, " }")

    return concat(ret, "")
end

--[[
    Object metatable
--]]

objectMt.__index = function(self, key)
    return get(self, objectProto, key)
end

objectMt.__newindex = put

objectMt.__tostring = function(self)
    return coreObjects.objectToString(self)
end

objectMt.__tonumber = function(self)
    return 0/0
end

objectMt.__lt = function(a, b)
    return defaultValueNumber(a) < defaultValueNumber(b)
end

objectMt.__le = function(a, b)
    return defaultValueNumber(a) <= defaultValueNumber(b)
end

--[[
    Function metatable
--]]

local functionsProxyObjects = {}

setmetatable(functionsProxyObjects, {__mode = 'k'})

function coreObjects.getFunctionProxy(fun)
    local proxy = rawget(functionsProxyObjects, fun)
    if proxy == nil then
        proxy = coreObjects.obj({})
        rawset(functionsProxyObjects, fun, proxy)
    end
    return proxy
end

functionMt.__index = function(self, key)
    local proxy = coreObjects.getFunctionProxy(self)

    -- prototype attribute of functions should always "exist"
    if key == 'prototype' then
        if proxy.prototype == nil then
            proxy.prototype = coreObjects.obj({constructor = self})
        end
        return proxy.prototype
    end

    local value = rawget(proxy, key)
    if value ~= nil then
        return value
    end

    return get(proxy, functionProto, key)
end

functionMt.__newindex = function(self, key, value)
    local proxy = coreObjects.getFunctionProxy(self)
    put(proxy, key, value)
end

functionMt.__tostring = function(self)
    -- TODO: approximation
    return "[Function]"
end

functionMt.__tonumber = function(self)
    return 0/0
end

functionMt.__lt = function(a, b)
    return defaultValueNumber(a) < defaultValueNumber(b)
end

functionMt.__le = function(a, b)
    return defaultValueNumber(a) <= defaultValueNumber(b)
end

debug.setmetatable((function () end), functionMt)

--[[
    Array metatable
--]]

arrayMt.__index = function(self, key)
    return get(self, arrayProto, key)
end

arrayMt.__newindex = function(self, key, value)
    if type(key) == 'number' then
        local length = rawget(self, 'length') or 0
        rawset(self, 'length', max(length, key + 1))
    end
    put(self, key, value)
end

arrayMt.__tostring = function(self)
    local ret = {"[ "}
    local elements = {}

    local props = coreObjects.props(self, false, false)
    for _, key in ipairs(props) do
        local k = key
        local v = self[key]

        if type(v) == "string" then
            v = "'" .. tostring(v) .. "'"
        else
            v = tostring(v)
        end

        if type(k) == "number" then
            tinsert(elements, v)
        else
            tinsert(elements, k .. ": " .. v)
        end
    end
    tinsert(ret, concat(elements, ", "))
    tinsert(ret, " ]")

    return concat(ret, "")
end

arrayMt.__tonumber = function(self)
    return 0/0
end

arrayMt.__lt = function(a, b)
    return defaultValueNumber(a) < defaultValueNumber(b)
end
arrayMt.__le = function(a, b)
    return defaultValueNumber(a) <= defaultValueNumber(b)
end

--[[
    Boolean metatable
--]]

booleanMt.__index = function(self, key)
    return get(nil, booleanProto, key)
end

-- immutable
booleanMt.__newindex = function() end

booleanMt.__lt = function(a, b)
    local numValueA = a and 1 or 0

    if type(b) == "boolean" then
        return numValueA < (b and 1 or 0)
    end

    return numValueA < defaultValueNumber(b)
end

booleanMt.__le = function(a, b)
    local numValueA = a and 1 or 0

    if type(b) == "boolean" then
        return numValueA <= (b and 1 or 0)
    end

    return numValueA <= defaultValueNumber(b)
end

booleanMt.__tonumber = function(self)
    return self and 1 or 0
end

booleanMt.__sub = function(a, b)
    local ta, tb = type(a), type(b)
    if ta == "boolean" then
        return (a and 1 or 0) - toNumber(b)
    else
        return toNumber(a)  - (b and 1 or 0)
    end
end

booleanMt.__div = function(a, b)
    local ta, tb = type(a), type(b)
    if ta == "boolean" then
        return (a and 1 or 0) / toNumber(b)
    else
        return toNumber(a)  / (b and 1 or 0)
    end
end

booleanMt.__mul = function(a, b)
    local ta, tb = type(a), type(b)
    if ta == "boolean" then
        return (a and 1 or 0) * toNumber(b)
    else
        return toNumber(a)  * (b and 1 or 0)
    end
end

debug.setmetatable(true, booleanMt)

--[[
    Number metatable
--]]

numberMt.__index = function(self, key)
    return get(nil, numberProto, key)
end

-- immutable
numberMt.__newindex = function() end

numberMt.__lt = function(a, b)
    local tb = type(b)
    if tb == "string" then
        return a < tonumber(b)
    end
    if tb == "boolean" then
        return a < (b and 1 or 0)
    end
    if b == null then
        return a < 0
    end
    if tb == "table" then
        return a < defaultValueNumber(b)
    end

    return false
end

numberMt.__le = function(a, b)
    local tb = type(b)
    if tb == "string" then
        return a <= tonumber(b)
    end
    if tb == "boolean" then
        return a <= (b and 1 or 0)
    end
    if b == null then
        return a <= 0
    end
    if tb == "table" then
        return a <= defaultValueNumber(b)
    end

    return false
end

debug.setmetatable(0, numberMt)

--[[
    String metatable
--]]

stringMt.__index = function(self, key)

    local length = strlen(self)

    if key == "length" then
        return length
    end

    -- Access characters of a string like an array
    local num = tonumber(key)
    if num then
        if num < length then
            return strsub(self, num + 1, num + 1)
        end
        return nil
    end

    return get(nil, stringProto, key)
end

-- immutable
stringMt.__newindex = function() end

stringMt.__lt = function(a, b)
    local tb = type(b)
    if tb == "number" then
        return tonumber(a) < b
    end
    if tb == "boolean" then
        return tonumber(a) < (b and 1 or 0)
    end
    if b == null then
        return a < 0
    end

    return a < defaultValueNumber(b)
end

stringMt.__le = function(a, b)
    local t = type(b)
    if t == "number" then
        return tonumber(a) <= b
    end
    if t == "boolean" then
        return tonumber(a) <= (b and 1 or 0)
    end
    if b == null then
        return tonumber(a) <= 0
    end

    return a <= defaultValueNumber(b)
end

stringMt.__add= function(a, b)
    return tostring(a) .. tostring(b)
end

stringMt.__tonumber = function(self)
    return tonumber(self) or 0/0
end

debug.setmetatable("", stringMt)

--[[
    Nil metatable
--]]

undefinedMt.__tostring = function ()
    return 'undefined'
end

undefinedMt.__add = function (a, b)
    local ta, tb = type(a), type(b)
    if ta == "number" or tb == "number" or
        ta == "boolean" or tb == "boolean" then
        return 0/0
    end

    if ta == "string" or tb == "string" then
        return tostring(a) .. tostring(b)
    end

    return a + b
end

undefinedMt.__sub = function ()
    return 0/0
end
undefinedMt.__mul = function ()
    return 0/0
end
undefinedMt.__div = function ()
    return 0/0
end
undefinedMt.__mod = function ()
    return 0/0
end
undefinedMt.__pow = function ()
    return 0/0
end

undefinedMt.__lt = function ()
    return false
end
undefinedMt.__le = function ()
    return false
end

undefinedMt.__tonumber = function ()
    return 0/0
end

debug.setmetatable(nil, undefinedMt)

--[[
    Support functions
--]]

-- Inline creation of object: {att1: "...", att2: ...}
function coreObjects.obj(o)
    return setmetatable(o, objectMt)
end

-- Inline creation of array: [..., ...]
function coreObjects.array(arr, length)
    rawset(arr, 'length', length)
    return setmetatable(arr, arrayMt)
end

-- Inline creation of RegExp: /.../
function coreObjects.regexp(pattern, flags)
    RegExp = RegExp or require("castl.constructor.regexp")
    return coreObjects.new(RegExp, pattern, flags)
end

-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/new
function coreObjects.new(f, ...)
    if type(f) ~= "function" then
        error(errorHelper.newTypeError(typeof(f) .. " is not a function"))
    end

    local o = {}
    setNewMetatable(o, f.prototype)
    local ret = f(o, ...)

    -- http://stackoverflow.com/a/3658673
    local tr = type(ret)
    if tr == "table" or tr == "function" then
        return ret
    end

    return o
end

function coreObjects.arguments(...)
    local args, obj = pack(...), {}

    -- make a 0 based numbering array like
    -- and we ignore the first argument (= this)
    for i = 2, args.n do
        obj[i - 2] = args[i]
    end

    obj.length = args.n - 1

    local mt = {
        __index = function (self, key)
            return get(self, objectProto, key)
        end,
        __newindex = function (self, key, value)
            return put(self, key, value)
        end,
        __tostring = function(self)
            return coreObjects.objectToString(self)
        end,
        __tonumber = function()
            return 0/0
        end,
        _prototype = "Arguments"
    }

    setmetatable(obj, mt)

    return obj
end

function coreObjects.instanceof(object, class)
    if type(class) ~= "function" then
        error(errorHelper.newTypeError("Expecting a function in instanceof check, but got " .. tostring(class)))
    end

    if class.prototype then
        local classPrototypeAttribute = class.prototype
        local objectPrototype = getPrototype(object)

        while objectPrototype do
            if objectPrototype == classPrototypeAttribute then
                return true
            end
            objectPrototype = getPrototype(objectPrototype)
        end
    end
    return false
end

function coreObjects.props (arg, inherited, enumAll)
    if type(arg) == 'function' then
        arg = coreObjects.getFunctionProxy(arg)
    end

    local ret = {}

    local mt = getmetatable(arg)
    local isArrayLike = (mt and (mt._prototype == arrayProto or mt._prototype == "Arguments" or mt._prototype == stringProto));

    if isArrayLike then
        return coreObjects.propsArr(arg, inherited, enumAll)
    elseif type(arg) == 'table' then
        return coreObjects.propsObj(arg, inherited, enumAll)
    elseif type(arg) == 'string' then
        for i = 0, arg.length - 1 do
            tinsert(ret, i)
        end
    end

    return ret
end

function coreObjects.propsObj(arg, inherited, enumAll)
    local ret = {}
    repeat
        for i, j in pairs(arg) do
            tinsert(ret, i)
        end
        arg = (getmetatable(arg) or {})._prototype
    until not inherited or arg == nil or arg == objectProto

    -- sort keys
    sort(ret, function(a, b)
        a = tonumber(a) or a
        b = tonumber(b) or b

        local ta, tb = type(a), type(b)
        if ta == "number" and tb == "string" then
            return true
        elseif ta == "string" and tb == "number" then
            return false
        end
        return a < b
    end)

    return ret
end

function coreObjects.propsArr(arg, inherited, enumAll)
    local ret = {}

    for i, j in pairs(arg) do
        if enumAll or not (i == "length") then
            tinsert(ret, i)
        end
    end

    -- sort keys
    sort(ret, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == "number" and tb == "string" then
            return true
        elseif ta == "string" and tb == "number" then
            return false
        end
        return a < b
    end)

    return ret
end

--[[
    Prototypes inherit from object (not the same as ECMAScript spec)
--]]

coreObjects.obj(functionProto)
coreObjects.obj(arrayProto)
coreObjects.obj(booleanProto)
coreObjects.obj(numberProto)
coreObjects.obj(stringProto)
coreObjects.obj(dateProto)
coreObjects.obj(regexpProto)
coreObjects.obj(errorProto)

coreObjects.obj(rangeErrorProto)
coreObjects.obj(referenceErrorProto)
coreObjects.obj(syntaxErrorProto)
coreObjects.obj(typeErrorProto)
coreObjects.obj(regexpProto)

--[[
    Export objectMt and arrayMt for JSON.parse
--]]

coreObjects.objectMt = objectMt
coreObjects.arrayMt = arrayMt


-- global this
coreObjects.this = coreObjects.obj({})

return coreObjects
