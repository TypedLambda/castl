var assert = require("assert");

// FunctionExpression
var f = function () {
    return true;
}

assert(f());

// FunctionDeclaration
function f2() {
    return true;
}

assert(f2());

// Anonymous function call
(function () {
    assert(true);
})();

if (!(function () {
    return true;
})()) {
    assert(false);
}

// Params
function f3(a, b) {
    assert(a === 1);
    assert(b === 2);
}

f3(1, 2);

// Arguments

function f4(a) {
    return arguments.length;
}

assert(f4(1, 2, 3, 4) === 4);

function f5() {
    return arguments[4];
}

assert(f5(1, 2, 3, 4, 21) === 21);
