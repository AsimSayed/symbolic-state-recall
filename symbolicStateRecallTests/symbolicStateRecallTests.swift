// SymbolicStateRecallTests.swift
// SymbolicStateRecall
//
// Unit tests for the Tokenizer, Parser, and AST construction.

import XCTest
@testable import symbolicStateRecall

class TokenizerTests: XCTestCase {

    func testSimpleExpression() throws {
        let tokenizer = Tokenizer(input: "x^2 + 3")
        let tokens = try tokenizer.tokenize()

        // x, ^, 2, +, 3, eof
        XCTAssertEqual(tokens.count, 6)
        XCTAssertEqual(tokens[0].type, .variable)
        XCTAssertEqual(tokens[0].text, "x")
        XCTAssertEqual(tokens[1].type, .power)
        XCTAssertEqual(tokens[2].type, .number)
        XCTAssertEqual(tokens[2].text, "2")
        XCTAssertEqual(tokens[3].type, .plus)
        XCTAssertEqual(tokens[4].type, .number)
        XCTAssertEqual(tokens[4].text, "3")
    }

    func testFunctionName() throws {
        let tokenizer = Tokenizer(input: "sin(x)")
        let tokens = try tokenizer.tokenize()

        XCTAssertEqual(tokens[0].type, .funcName("sin"))
        XCTAssertEqual(tokens[1].type, .leftParen)
        XCTAssertEqual(tokens[2].type, .variable)
        XCTAssertEqual(tokens[3].type, .rightParen)
    }

    func testIntegralKeyword() throws {
        let tokenizer = Tokenizer(input: "int_0^1 x^2 dx")
        let tokens = try tokenizer.tokenize()

        XCTAssertEqual(tokens[0].type, .intKeyword)
        XCTAssertEqual(tokens[1].type, .underscore)
        XCTAssertEqual(tokens[2].type, .number)
        XCTAssertEqual(tokens[2].text, "0")
        XCTAssertEqual(tokens[3].type, .power)  // ^ for upper bound
        XCTAssertEqual(tokens[4].type, .number)
        XCTAssertEqual(tokens[4].text, "1")
    }

    func testLimitArrow() throws {
        let tokenizer = Tokenizer(input: "lim_x->0 sin(x)/x")
        let tokens = try tokenizer.tokenize()

        XCTAssertEqual(tokens[0].type, .limKeyword)
        XCTAssertEqual(tokens[1].type, .underscore)
        XCTAssertEqual(tokens[2].type, .variable)
        XCTAssertEqual(tokens[3].type, .arrow)
        XCTAssertEqual(tokens[4].type, .number)
    }

    func testEquation() throws {
        let tokenizer = Tokenizer(input: "x + 1 = 5")
        let tokens = try tokenizer.tokenize()

        let types = tokens.map { $0.type }
        XCTAssertTrue(types.contains(.equals))
    }
}

class ParserTests: XCTestCase {

    let parser = Parser()

    func testSimpleValue() throws {
        let node = try parser.parse("42")
        XCTAssertEqual(node.type, .side)
        XCTAssertEqual(node.children.count, 1)
        XCTAssertEqual(node.children[0].type, .value)
        XCTAssertEqual(node.children[0].value, "42")
    }

    func testSimpleEquation() throws {
        let node = try parser.parse("x = 5")
        XCTAssertEqual(node.type, .equation)
        XCTAssertEqual(node.children.count, 2)  // part 1, part 2
        XCTAssertEqual(node.children[0].value, "1")
        XCTAssertEqual(node.children[1].value, "2")
    }

    func testPowerExpression() throws {
        let node = try parser.parse("x^2")
        XCTAssertEqual(node.type, .side)
        let power = node.children[0]
        XCTAssertEqual(power.type, .power)
        XCTAssertEqual(power.children.count, 2)
        XCTAssertEqual(power.children[0].value, "x")  // base
        XCTAssertEqual(power.children[1].value, "2")  // exponent
        XCTAssertEqual(power.label, "x squared")
    }

    func testCubedLabel() throws {
        let node = try parser.parse("y^3")
        let power = node.children[0]
        XCTAssertEqual(power.label, "y cubed")
    }

    func testFraction() throws {
        let node = try parser.parse("(x+3)/2")
        let item = node.children[0]  // top-level item on left side
        XCTAssertEqual(item.type, .fraction)
        XCTAssertEqual(item.children.count, 2)
    }

    func testSqrt() throws {
        let node = try parser.parse("sqrt(x+1)")
        let item = node.children[0]
        XCTAssertEqual(item.type, .root)
        XCTAssertEqual(item.children.count, 1)
        XCTAssertTrue(item.label.contains("square root"))
    }

    func testNthRoot() throws {
        let node = try parser.parse("root(3, x)")
        let item = node.children[0]
        XCTAssertEqual(item.type, .nthRoot)
        XCTAssertEqual(item.children.count, 2)
    }

    func testFunction() throws {
        let node = try parser.parse("sin(x)")
        let item = node.children[0]
        XCTAssertEqual(item.type, .function)
        XCTAssertEqual(item.value, "sin")
        XCTAssertEqual(item.children.count, 1)
    }

    func testDefiniteIntegral() throws {
        let node = try parser.parse("int_0^1 x^2 dx")
        let item = node.children[0]
        XCTAssertEqual(item.type, .integral)
        XCTAssertEqual(item.children.count, 4)  // lower, upper, integrand, var
        XCTAssertEqual(item.children[0].value, "0")  // lower
        XCTAssertEqual(item.children[1].value, "1")  // upper
    }

    func testIndefiniteIntegral() throws {
        let node = try parser.parse("int x^2 dx")
        let item = node.children[0]
        XCTAssertEqual(item.type, .integral)
        XCTAssertEqual(item.children.count, 2)  // integrand, var
    }

    func testDerivative() throws {
        let node = try parser.parse("d/dx(x^2 + 3x)")
        let item = node.children[0]
        XCTAssertEqual(item.type, .derivative)
        XCTAssertEqual(item.children.count, 2)  // variable, expression
        XCTAssertEqual(item.children[0].value, "x")
    }

    func testLimit() throws {
        let node = try parser.parse("lim_x->0 sin(x)/x")
        let item = node.children[0]
        XCTAssertEqual(item.type, .limit)
        XCTAssertEqual(item.children.count, 3)  // variable, approach, expression
    }

    func testThreePartEquation() throws {
        let node = try parser.parse("a = b = c")
        XCTAssertEqual(node.type, .equation)
        XCTAssertEqual(node.children.count, 3)  // parts 1, 2, 3
        XCTAssertEqual(node.children[0].value, "1")
        XCTAssertEqual(node.children[1].value, "2")
        XCTAssertEqual(node.children[2].value, "3")
    }

    func testAdditionSplitsTopLevel() throws {
        let node = try parser.parse("x^2 + 3x + 5 = 20")
        XCTAssertEqual(node.type, .equation)

        let leftSide = node.children[0]
        XCTAssertEqual(leftSide.children.count, 3)  // x^2, +3x, +5

        let rightSide = node.children[1]
        XCTAssertEqual(rightSide.children.count, 1)  // 20
    }

    func testTopLevelIndex() throws {
        let (_, index) = try parser.parseAndIndex("x^2 + 3x = 5")

        XCTAssertEqual(index.count(line: 1, side: "1"), 2)
        XCTAssertEqual(index.count(line: 1, side: "2"), 1)

        let firstLeft = index.resolve(line: 1, side: "1", position: 1)
        XCTAssertNotNil(firstLeft)
        XCTAssertEqual(firstLeft?.type, .power)

        let rightItem = index.resolve(line: 1, side: "2", position: 1)
        XCTAssertNotNil(rightItem)
        XCTAssertEqual(rightItem?.value, "5")
    }

    func testComplexEquation() throws {
        // The example from the design doc
        let input = "int_0^1 (x^2 + 3x)/sqrt(x+1) dx + ln(y^3) = e^t"
        let (root, index) = try parser.parseAndIndex(input)

        // Should have left and right sides
        XCTAssertEqual(root.type, .equation)

        // Part 1: integral + ln(y^3)
        XCTAssertEqual(index.count(line: 1, side: "1"), 2)

        // Part 2: e^t
        XCTAssertEqual(index.count(line: 1, side: "2"), 1)

        // First item on part 1 should be integral
        let integral = index.resolve(line: 1, side: "1", position: 1)
        XCTAssertEqual(integral?.type, .integral)

        // Part 2 should be power (e^t)
        let rhs = index.resolve(line: 1, side: "2", position: 1)
        XCTAssertEqual(rhs?.type, .power)
    }
}

class NavigationTests: XCTestCase {

    var engine: NavigationEngine!
    var events: [NavigationEvent] = []

    class EventCollector: NavigationEngineDelegate {
        var events: [NavigationEvent] = []
        func navigationEngine(_ engine: NavigationEngine, didEmit event: NavigationEvent) {
            events.append(event)
        }
    }

    var collector: EventCollector!

    override func setUp() {
        super.setUp()
        engine = NavigationEngine()
        collector = EventCollector()
        engine.delegate = collector
    }

    func testRecallTrigger() throws {
        try engine.load(equation: "x^2 + 3 = 5")
        engine.trigger()

        XCTAssertEqual(collector.events.count, 1)
        if case .recallActivated = collector.events[0] {
            // Good
        } else {
            XCTFail("Expected recallActivated event")
        }
    }

    func testFullQueryPath() throws {
        try engine.load(equation: "x^2 + 3 = 5")
        engine.trigger()

        // Query: 1 L 1 → should get x^2
        engine.input(token: "1")
        engine.input(token: "L")
        engine.input(token: "1")

        XCTAssertNotNil(engine.selectedNode)
        XCTAssertEqual(engine.selectedNode?.type, .power)
    }

    func testInvalidIndex() throws {
        try engine.load(equation: "x = 5")
        engine.trigger()
        engine.input(token: "1")
        engine.input(token: "L")
        engine.input(token: "5")  // Invalid — only 1 item

        // Should get error but remain in recall mode
        let hasError = collector.events.contains { event in
            if case .error = event { return true }
            return false
        }
        XCTAssertTrue(hasError)
    }

    func testInsert() throws {
        try engine.load(equation: "x^2 = 5")
        engine.trigger()
        engine.input(token: "1")
        engine.input(token: "R")
        engine.input(token: "1")

        let text = engine.insertSelected()
        XCTAssertEqual(text, "5")
    }

    func testGoBack() throws {
        try engine.load(equation: "x^2 + 3 = 5")
        engine.trigger()
        engine.input(token: "1")
        engine.input(token: "L")
        engine.input(token: "1")  // x^2, opens power context

        // Now in power context, select exponent
        engine.input(token: "2")  // exponent = 2

        // Go back should return to power context
        engine.goBack()

        let hasBack = collector.events.contains { event in
            if case .navigatedBack = event { return true }
            return false
        }
        XCTAssertTrue(hasBack)
    }

    func testExitRecall() throws {
        try engine.load(equation: "x = 5")
        engine.trigger()
        engine.exitRecall()

        let hasExit = collector.events.contains { event in
            if case .recallExited = event { return true }
            return false
        }
        XCTAssertTrue(hasExit)
    }

    // MARK: - Tolerance Tests

    func testSingleLineSingleSideSkipsToIndex() throws {
        // Expression with no equals — should skip line and side selection
        try engine.load(equation: "x^2 + 3")
        engine.trigger()

        // Should be able to type index directly (no L/R needed)
        engine.input(token: "1")

        XCTAssertNotNil(engine.selectedNode)
        XCTAssertEqual(engine.selectedNode?.type, .power)  // x^2
    }

    func testSingleLineEquationRequiresSide() throws {
        // Equation with equals — should require L or R
        try engine.load(equation: "x^2 = 5")
        engine.trigger()

        // Typing L then 1 should work
        engine.input(token: "L")
        engine.input(token: "1")

        XCTAssertNotNil(engine.selectedNode)
        XCTAssertEqual(engine.selectedNode?.type, .power)  // x^2
    }

    func testSwitchSideAfterSelection() throws {
        // After selecting left side, typing R should switch to right
        try engine.load(equation: "x^2 = 5")
        engine.trigger()
        engine.input(token: "L")
        engine.input(token: "R")  // Switch to right side

        // Now select item 1 on right side
        engine.input(token: "1")

        XCTAssertNotNil(engine.selectedNode)
        XCTAssertEqual(engine.selectedNode?.value, "5")
    }

    func testDigitWhenExpectingSideOnSingleSide() throws {
        // Multi-line where one line has single side
        // This tests the input() tolerance path for pendingSide == nil + digit + single side
        try engine.loadMultiLine(equations: "x + 3\ny = 5")
        engine.trigger()

        // Line 1 (expression, single side) — type line then directly type index
        engine.input(token: "1")  // selects line 1, auto-selects L side
        engine.input(token: "1")  // should resolve to item 1 (x)

        XCTAssertNotNil(engine.selectedNode)
    }
}

class ParserEdgeCaseTests: XCTestCase {

    let parser = Parser()

    func testNegativeNumberAtStart() throws {
        let node = try parser.parse("-3x^2 + 5 = 0")
        XCTAssertEqual(node.type, .equation)
        // Part 1 should have 2 items: -3x^2, +5
        let part1 = node.children[0]
        XCTAssertEqual(part1.children.count, 2)
        // First item should contain "negative" in its label
        XCTAssertTrue(part1.children[0].label.contains("negative"))
    }

    func testNestedFractions() throws {
        let node = try parser.parse("(a/b)/(c/d)")
        let outerFrac = node.children[0]
        XCTAssertEqual(outerFrac.type, .fraction)
        XCTAssertEqual(outerFrac.children.count, 2)
    }

    func testImplicitMultiplyWithFunction() throws {
        let node = try parser.parse("2sin(x)")
        XCTAssertEqual(node.type, .side)
        // Should parse as 2 * sin(x), resulting in a term node
        let item = node.children[0]
        XCTAssertEqual(item.children.count, 2)  // 2 and sin(x)
    }

    func testImplicitMultiplyVariableFunction() throws {
        let node = try parser.parse("xcos(x)")
        XCTAssertEqual(node.type, .side)
        let item = node.children[0]
        XCTAssertEqual(item.children.count, 2)  // x and cos(x)
    }

    func testImplicitMultiplyParenGroups() throws {
        let node = try parser.parse("(x+1)(x-1)")
        XCTAssertEqual(node.type, .side)
        let item = node.children[0]
        XCTAssertEqual(item.children.count, 2)  // (x+1) and (x-1)
    }

    func testMultiDigitNumbers() throws {
        let node = try parser.parse("123^45")
        let power = node.children[0]
        XCTAssertEqual(power.type, .power)
        XCTAssertEqual(power.children[0].value, "123")
        XCTAssertEqual(power.children[1].value, "45")
    }

    func testDecimalBoundsInIntegral() throws {
        let node = try parser.parse("int_0.5^1.5 x dx")
        let integral = node.children[0]
        XCTAssertEqual(integral.type, .integral)
        XCTAssertEqual(integral.children[0].value, "0.5")
        XCTAssertEqual(integral.children[1].value, "1.5")
    }

    func testFourPartEquation() throws {
        let node = try parser.parse("a = b = c = d")
        XCTAssertEqual(node.type, .equation)
        XCTAssertEqual(node.children.count, 4)
        XCTAssertEqual(node.children[3].value, "4")
    }

    func testMismatchedParenThrows() throws {
        XCTAssertThrowsError(try parser.parse("(x + 3"))
    }

    func testPowerLabelFourth() throws {
        let node = try parser.parse("x^4")
        let power = node.children[0]
        XCTAssertEqual(power.label, "x to the fourth")
    }

    func testPowerLabelFifth() throws {
        let node = try parser.parse("x^5")
        let power = node.children[0]
        XCTAssertEqual(power.label, "x to the fifth")
    }

    func testNonBreakingSpaceTolerance() throws {
        // Non-breaking space between terms
        let input = "x\u{00A0}+\u{00A0}3"
        let node = try parser.parse(input)
        XCTAssertEqual(node.type, .side)
    }
}

class SerializerTests: XCTestCase {

    let parser = Parser()

    func testRoundTripValue() throws {
        let node = try parser.parse("42")
        let text = MathSerializer.serialize(node.children[0])
        XCTAssertEqual(text, "42")
    }

    func testRoundTripPower() throws {
        let node = try parser.parse("x^2")
        let text = MathSerializer.serialize(node.children[0])
        XCTAssertEqual(text, "x^2")
    }

    func testRoundTripFunction() throws {
        let node = try parser.parse("sin(x)")
        let text = MathSerializer.serialize(node.children[0])
        XCTAssertEqual(text, "sin(x)")
    }

    func testRoundTripSqrt() throws {
        let node = try parser.parse("sqrt(x+1)")
        // Serialization should produce "sqrt(...)" form
        let text = MathSerializer.serialize(node.children[0])
        XCTAssertTrue(text.hasPrefix("sqrt("))
    }
}

// MARK: - Math Extractor Tests

class MathExtractorTests: XCTestCase {

    func testIsProseDetectsNaturalLanguage() {
        XCTAssertTrue(MathExtractor.isProse("The answer to the equation is x^2 + 3 = 5 and it is useful"))
        XCTAssertTrue(MathExtractor.isProse("Given that we have a formula for calculating the area"))
    }

    func testIsProseRejectsPureMath() {
        XCTAssertFalse(MathExtractor.isProse("x^2 + 3x = 5"))
        XCTAssertFalse(MathExtractor.isProse("a + b = c"))
        XCTAssertFalse(MathExtractor.isProse("2x"))
    }

    func testExtractFromSimpleSentence() {
        let results = MathExtractor.extractMath(from: "The equation is x^2 + 3 = 5 for all values")
        XCTAssertFalse(results.isEmpty, "Should extract at least one math expression")
        // The extracted expression should parse successfully
        let parser = Parser()
        XCTAssertNotNil(try? parser.parse(results[0]))
    }

    func testExtractFromSentenceWithEquals() {
        let results = MathExtractor.extractMath(from: "We know that a + b = c so we can substitute")
        XCTAssertFalse(results.isEmpty)
        let parser = Parser()
        XCTAssertNotNil(try? parser.parse(results[0]))
    }

    func testExtractMultipleEquations() {
        let text = "First we have x = 5. Then y = 10."
        let results = MathExtractor.extractMath(from: text)
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testNoMathInPureProse() {
        let results = MathExtractor.extractMath(from: "The quick brown fox jumps over the lazy dog")
        XCTAssertTrue(results.isEmpty)
    }

    func testExtractWithParentheses() {
        let results = MathExtractor.extractMath(from: "Consider the function f(x) = (x + 1)^2 in this context")
        XCTAssertFalse(results.isEmpty)
    }
}
