//
//  BigIntegerTest.swift
//  BigIntegerTest
//
//  Created by OOPer in cooperation with shlab.jp, on 2018/1/21.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//

import XCTest

class BigIntegerTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStringConversion() {
        let testData: [(str: String, radix: Int)] = [
            ("0", 10),
            ("1", 10),
            ("9", 10),
            ("10", 10),
            ("99", 10),
            ("100", 10),
            ("999", 10),
            ("100000", 10),
            ("999999", 10),
            ("100000000", 10),
            ("999999999", 10),
            ("100000000000", 10),
            ("999999999999", 10),
            ("100000000000000", 10),
            ("999999999999999", 10),
            ("100000000000000000", 10),
            ("999999999999999999", 10),
            ("100000000000000000000", 10),
            ("999999999999999999999", 10),
            ("100000000000000000000000", 10),
            ("999999999999999999999999", 10),
            ("-1", 10),
            ("-9", 10),
            ("-10", 10),
            ("-99", 10),
            ("-100", 10),
            ("-999", 10),
            ("-100000", 10),
            ("-999999", 10),
            ("-100000000", 10),
            ("-999999999", 10),
            ("-100000000000", 10),
            ("-999999999999", 10),
            ("-100000000000000", 10),
            ("-999999999999999", 10),
            ("-100000000000000000", 10),
            ("-999999999999999999", 10),
            ("-100000000000000000000", 10),
            ("-999999999999999999999", 10),
            ("-100000000000000000000000", 10),
            ("-999999999999999999999999", 10),
            ("100000000000000000000000000000000000", 10),
        ]
        for (str, radix) in testData {
            let bi = BigInteger(str, radix: radix)!
            let str2 = bi.toString(radix: radix)
            XCTAssertEqual(str, str2)
        }
    }
    
    func testRemainder() {
        let testData: [(String, String, String)] = [
            ("1", "1", "1"),
            ("1", "-1", "-1"),
            ("-1", "1", "-1"),
            ("-1", "-1", "1"),
            ("10", "100", "1000"),
            ("1000", "1000000", "1000000000"),
            ("1000000000000000", "100000000000000000000", "100000000000000000000000000000000000"),
            ("100000000000000000000", "1000000000000000", "100000000000000000000000000000000000"),
            ("-1000000000000000", "100000000000000000000", "-100000000000000000000000000000000000"),
            ("1000000000000000", "-100000000000000000000", "-100000000000000000000000000000000000"),
            ("-1000000000000000", "-100000000000000000000", "100000000000000000000000000000000000"),
            ("100000", "-1000000000000000000000000000000", "-100000000000000000000000000000000000"),
            ]
        for (xStr, yStr, multResult) in testData {
            let mr = BigInteger(multResult)!
            let y = BigInteger(yStr)!
            if !y.isZero {
                let actualResult = (mr % y).toString()
                XCTAssertEqual(actualResult, "0")
            }
            let x = BigInteger(xStr)!
            if !x.isZero {
                let actualResult = (mr % x).toString()
                XCTAssertEqual(actualResult, "0")
            }
        }
        let testData2: [(String, String, String)] = [
            ("1", "1", "0"),
            ("1", "-1", "0"),
            ("-1", "1", "0"),
            ("-1", "-1", "0"),
            ("1234", "10", "4"),
            ("1234", "100", "34"),
            ("1000000", "12345678901234567890", "1000000"),
            ("1000000", "-12345678901234567890", "1000000"),
            ("-1000000", "12345678901234567890", "-1000000"),
            ("-1000000", "-12345678901234567890", "-1000000"),
            ("1234567890", "1000000", "567890"),
            ("-1234567890", "1000000", "-567890"),
            ("1234567890", "-1000000", "567890"),
            ("-1234567890", "-1000000", "-567890"),
            ("123456789012345678901234567890123456", "100000000000000000000", "78901234567890123456"),
            ("123456789012345678901234567890123456", "1000000000000000", "234567890123456"),
            ("-123456789012345678901234567890123456", "100000000000000000000", "-78901234567890123456"),
            ("-123456789012345678901234567890123456", "1000000000000000", "-234567890123456"),
            ("123456789012345678901234567890123456", "-100000000000000000000", "78901234567890123456"),
            ("123456789012345678901234567890123456", "-1000000000000000", "234567890123456"),
            ("-123456789012345678901234567890123456", "-100000000000000000000", "-78901234567890123456"),
            ("-123456789012345678901234567890123456", "-1000000000000000", "-234567890123456"),
            ("123456789012345678901234567890123456", "1000000000000000000000000000000", "789012345678901234567890123456"),
            ("123456789012345678901234567890123456", "100000", "23456"),
            ("-123456789012345678901234567890123456", "1000000000000000000000000000000", "-789012345678901234567890123456"),
            ("-123456789012345678901234567890123456", "100000", "-23456"),
            ("123456789012345678901234567890123456", "-1000000000000000000000000000000", "789012345678901234567890123456"),
            ("123456789012345678901234567890123456", "-100000", "23456"),
            ("-123456789012345678901234567890123456", "-1000000000000000000000000000000", "-789012345678901234567890123456"),
            ("-123456789012345678901234567890123456", "-100000", "-23456"),
            ]
        for (dividendStr, divisorStr, expected) in testData2 {
            let x = BigInteger(dividendStr)!
            let y = BigInteger(divisorStr)!
            if !y.isZero {
                let actualResult = (x % y).toString()
                XCTAssertEqual(actualResult, expected)
            }
        }
        let testData3: [(String, String, String)] = [
            ("-8000000000000000", "8000000000000000", "0")
        ]
        for (dividendStr, divisorStr, expected) in testData3 {
            let x = BigInteger(dividendStr, radix: 16)!
            let y = BigInteger(divisorStr, radix: 16)!
            if !y.isZero {
                let actualResult = (x % y).toString()
                XCTAssertEqual(actualResult, expected)
            }
        }
    }

    func testShift() {
        let testData: [(String, Int, String, String)] = [
            ("1", 0, "1", "1"),
            ("1", 1, "0", "2"),
            ("1", 35, "0", "800000000"),
            ("1", 64, "0", "10000000000000000"),
            ("1", 99, "0", "8000000000000000000000000"),
            ("7FFFFFFFFFFFFFFFFFFF", 0, "7FFFFFFFFFFFFFFFFFFF", "7FFFFFFFFFFFFFFFFFFF"),
            ("7FFFFFFFFFFFFFFFFFFF", 1, "3FFFFFFFFFFFFFFFFFFF", "FFFFFFFFFFFFFFFFFFFE"),
            ("7FFFFFFFFFFFFFFFFFFF", 35, "FFFFFFFFFFF", "3FFFFFFFFFFFFFFFFFFF800000000"),
            ("7FFFFFFFFFFFFFFFFFFF", 64, "7FFF", "7FFFFFFFFFFFFFFFFFFF0000000000000000"),
            ("7FFFFFFFFFFFFFFFFFFF", 99, "0", "3FFFFFFFFFFFFFFFFFFF8000000000000000000000000"),
            ("7FFFFFFFFFFFFFFFFFFF", 115, "0", "3FFFFFFFFFFFFFFFFFFF80000000000000000000000000000"),
            ("7FFFFFFFFFFFFFFFFFFF", 131, "0", "3FFFFFFFFFFFFFFFFFFF800000000000000000000000000000000"),
            ("-1", 0, "-1", "-1"),
            ("-1", 1, "-1", "-2"),
            ("-1", 35, "-1", "-800000000"),
            ("-1", 64, "-1", "-10000000000000000"),
            ("-1", 99, "-1", "-8000000000000000000000000"),
            ("-7FFFFFFFFFFFFFFFFFFF", 0, "-7FFFFFFFFFFFFFFFFFFF", "-7FFFFFFFFFFFFFFFFFFF"),
            ("-7FFFFFFFFFFFFFFFFFFF", 1, "-40000000000000000000", "-FFFFFFFFFFFFFFFFFFFE"),
            ("-7FFFFFFFFFFFFFFFFFFF", 35, "-100000000000", "-3FFFFFFFFFFFFFFFFFFF800000000"),
            ("-7FFFFFFFFFFFFFFFFFFF", 64, "-8000", "-7FFFFFFFFFFFFFFFFFFF0000000000000000"),
            ("-7FFFFFFFFFFFFFFFFFFF", 99, "-1", "-3FFFFFFFFFFFFFFFFFFF8000000000000000000000000"),
            ("-7FFFFFFFFFFFFFFFFFFF", 115, "-1", "-3FFFFFFFFFFFFFFFFFFF80000000000000000000000000000"),
            ("-7FFFFFFFFFFFFFFFFFFF", 131, "-1", "-3FFFFFFFFFFFFFFFFFFF800000000000000000000000000000000"),
            ]
        for (xStr, bits, expectedRight, expectedLeft) in testData {
            let x = BigInteger(xStr, radix: 16)!
            let actualResult = (x >> bits).toString(radix: 16)
            XCTAssertEqual(actualResult, expectedRight, "\(xStr) >> \(bits)")
            let actualResult2 = (x << bits).toString(radix: 16)
            XCTAssertEqual(actualResult2, expectedLeft, "\(xStr) << \(bits)")
            let actualResult3 = (x >> -bits).toString(radix: 16)
            XCTAssertEqual(actualResult3, expectedLeft, "\(xStr) >> \(-bits)")
            let actualResult4 = (x << -bits).toString(radix: 16)
            XCTAssertEqual(actualResult4, expectedRight, "\(xStr) << \(-bits)")
        }
    }

    func testDivision() {
        let testData: [(String, String, String)] = [
            ("1", "1", "1"),
            ("1", "-1", "-1"),
            ("-1", "1", "-1"),
            ("-1", "-1", "1"),
            ("10", "100", "1000"),
            ("1000", "1000000", "1000000000"),
            ("1000000000000000", "100000000000000000000", "100000000000000000000000000000000000"),
            ("100000000000000000000", "1000000000000000", "100000000000000000000000000000000000"),
            ("-1000000000000000", "100000000000000000000", "-100000000000000000000000000000000000"),
            ("1000000000000000", "-100000000000000000000", "-100000000000000000000000000000000000"),
            ("-1000000000000000", "-100000000000000000000", "100000000000000000000000000000000000"),
            ("100000", "-1000000000000000000000000000000", "-100000000000000000000000000000000000"),
            ]
        for (xStr, yStr, multResult) in testData {
            let mr = BigInteger(multResult)!
            let y = BigInteger(yStr)!
            if !y.isZero {
                let actualResult = (mr / y).toString()
                XCTAssertEqual(actualResult, xStr)
            }
            let x = BigInteger(xStr)!
            if !x.isZero {
                let actualResult2 = (mr / x).toString()
                XCTAssertEqual(actualResult2, yStr)
            }
        }
        let testData2: [(String, String, String)] = [
            ("1000000", "12345678901234567890", "0"),
            ("1000000", "-12345678901234567890", "0"),
            ("-1000000", "12345678901234567890", "0"),
            ("-1000000", "-12345678901234567890", "0"),
            ]
        for (dividendStr, divisorStr, expected) in testData2 {
            let x = BigInteger(dividendStr)!
            let y = BigInteger(divisorStr)!
            if !y.isZero {
                let actualResult = (x / y).toString()
                XCTAssertEqual(actualResult, expected)
            }
        }
        let testData3: [(String, String, String)] = [
            ("-8000000000000000", "8000000000000000", "-1")
        ]
        for (dividendStr, divisorStr, expected) in testData3 {
            let x = BigInteger(dividendStr, radix: 16)!
            let y = BigInteger(divisorStr, radix: 16)!
            if !y.isZero {
                let actualResult = (x / y).toString()
                XCTAssertEqual(actualResult, expected)
            }
        }
    }

    func testConstructor() {
        let testData: [Int64] = [
            0,
            1,
            9,
            10,
            99,
            100,
            999,
            100000,
            999999,
            100000000,
            999999999,
            100000000000,
            999999999999,
            100000000000000,
            999999999999999,
            100000000000000000,
            999999999999999999,
            -1,
            -9,
            -10,
            -99,
            -100,
            -999,
            -100000,
            -999999,
            -100000000,
            -999999999,
            -100000000000,
            -999999999999,
            -100000000000000,
            -999999999999999,
            -100000000000000000,
            -999999999999999999,
        ]
        for val in testData {
            let expected = String(val)
            if let uval = UInt8(exactly: val) {
                let bi = BigInteger(uval)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let ival = Int8(exactly: val) {
                let bi = BigInteger(ival)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let uval = UInt16(exactly: val) {
                let bi = BigInteger(uval)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let ival = Int16(exactly: val) {
                let bi = BigInteger(ival)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let uval = UInt32(exactly: val) {
                let bi = BigInteger(uval)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let ival = Int32(exactly: val) {
                let bi = BigInteger(ival)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let uval = UInt64(exactly: val) {
                let bi = BigInteger(uval)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let ival = Int64(exactly: val) {
                let bi = BigInteger(ival)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let uval = UInt(exactly: val) {
                let bi = BigInteger(uval)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
            if let ival = Int(exactly: val) {
                let bi = BigInteger(ival)
                let actual = bi.toString()
                XCTAssertEqual(actual, expected)
            }
        }
    }

    func testMultiplication() {
        let testData: [(String, String, String)] = [
            ("0", "0", "0"),
            ("0", "1", "0"),
            ("1", "1", "1"),
            ("1", "-1", "-1"),
            ("-1", "-1", "1"),
            ("10", "100", "1000"),
            ("1000", "1000000", "1000000000"),
            ("1000000000000000", "100000000000000000000", "100000000000000000000000000000000000"),
            ("-1000000000000000", "100000000000000000000", "-100000000000000000000000000000000000"),
            ("1000000000000000", "-100000000000000000000", "-100000000000000000000000000000000000"),
            ("-1000000000000000", "-100000000000000000000", "100000000000000000000000000000000000"),
            ("100000", "-1000000000000000000000000000000", "-100000000000000000000000000000000000"),
        ]
        for (xStr, yStr, expectedResult) in testData {
            let x = BigInteger(xStr)!
            let y = BigInteger(yStr)!
            let actualReult = (x * y).toString()
            XCTAssertEqual(actualReult, expectedResult, "(\(xStr))*(\(yStr))")
            let actualReult2 = (y * x).toString()
            XCTAssertEqual(actualReult2, expectedResult, "(\(yStr))+(\(xStr))")
        }
    }
    
    func testSubtraction() {
        let testData: [(String, String, String)] = [
            ("0", "0", "0"),
            ("0", "1", "-1"),
            ("1", "0", "1"),
            ("1", "1", "0"),
            ("1", "-1", "2"),
            ("-1", "1", "-2"),
            ("-1", "-1", "0"),
            ("10", "100", "-90"),
            ("1000", "1000000", "-999000"),
            ("1000000000000000", "100000000000000000000", "-99999000000000000000"),
            ("100000000000000000000", "1000000000000000", "99999000000000000000"),
            ("-1000000000000000", "100000000000000000000", "-100001000000000000000"),
            ("1000000000000000", "-100000000000000000000", "100001000000000000000"),
            ("-1000000000000000", "-100000000000000000000", "99999000000000000000"),
            ]
        for (xStr, yStr, expectedResult) in testData {
            let x = BigInteger(xStr)!
            let y = BigInteger(yStr)!
            let actualReult = (x - y).toString()
            XCTAssertEqual(actualReult, expectedResult)
        }
    }
    
    func testAddition() {
        let testData: [(String, String, String)] = [
            ("0", "0", "0"),
            ("0", "1", "1"),
            ("1", "1", "2"),
            ("1", "-1", "0"),
            ("-1", "-1", "-2"),
            ("10", "100", "110"),
            ("1000", "1000000", "1001000"),
            ("1000000000000000", "100000000000000000000", "100001000000000000000"),
            ("-1000000000000000", "100000000000000000000", "99999000000000000000"),
            ("1000000000000000", "-100000000000000000000", "-99999000000000000000"),
            ("-1000000000000000", "-100000000000000000000", "-100001000000000000000"),
            ]
        for (xStr, yStr, expectedResult) in testData {
            let x = BigInteger(xStr)!
            let y = BigInteger(yStr)!
            let actualReult = (x + y).toString()
            XCTAssertEqual(actualReult, expectedResult, "(\(xStr))+(\(yStr))")
            let actualReult2 = (y + x).toString()
            XCTAssertEqual(actualReult2, expectedResult, "(\(yStr))+(\(xStr))")
        }
    }
    
    func testLogicalNot() {
        let testData: [(String, String)] = [
            ("0", "-1"),
            ("1", "-2"),
            ("100000000000", "-100000000001"),
            ("1000000000000000000000", "-1000000000000000000001"),
        ]
        for (xStr, yStr) in testData {
            let x = BigInteger(xStr)!
            let y = BigInteger(yStr)!
            let actualReult = (~x).toString()
            XCTAssertEqual(actualReult, yStr, "~\(xStr)")
            let actualReult2 = (~y).toString()
            XCTAssertEqual(actualReult2, xStr, "~\(yStr)")
        }
    }
    
    func testMinus() {
        let testData: [(String, String)] = [
            ("0", "0"),
            ("1", "-1"),
            ("2", "-2"),
            ("100000000000", "-100000000000"),
            ("1000000000000000000000", "-1000000000000000000000"),
            ]
        for (xStr, yStr) in testData {
            let x = BigInteger(xStr)!
            let y = BigInteger(yStr)!
            let actualReult = (-x).toString()
            XCTAssertEqual(actualReult, yStr, "-(\(xStr))")
            let actualReult2 = (-y).toString()
            XCTAssertEqual(actualReult2, xStr, "-(\(yStr))")
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
