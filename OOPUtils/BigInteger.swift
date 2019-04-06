//
//  BigInteger.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2018/1/21.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Copyright (c) 2017-2018, OOPer(NAGATA, Atsuyuki)
 All rights reserved.
 
 Use of any parts(functions, classes or any other program language components)
 of this file is permitted with no restrictions, unless you
 redistribute or use this file in its entirety without modification.
 In this case, providing any sort of warranties or not is the user's responsibility.
 
 Redistribution and use in source and/or binary forms, without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

///A mutable class which can contain unnormalized long precision integer.
private class BigIntegerBuffer: Hashable {
    fileprivate typealias Word = UInt64 //Needs to be an unsigned integer, the size needs to be a multilpe of `UInt`
    fileprivate typealias SignedWord = Int64 //Signed counterpart of Word
    fileprivate typealias Half = UInt32 //Needs to be an unsigned integer, exactly the half size of `Word`
    fileprivate typealias SignedHalf = Int32 //Signed counterpart of Half
    fileprivate typealias Quarter = UInt16 //Needs to be an unsigned integer, exactly the half size of `Half`

    fileprivate static let WordBits = MemoryLayout<Word>.size * 8
    fileprivate static let HalfBits = MemoryLayout<Half>.size * 8
    fileprivate static let QuarterBits = MemoryLayout<Quarter>.size * 8

    private var allocated: Int
    fileprivate var count: Int
    fileprivate var wordPtr: UnsafeMutablePointer<Word>?
    
    fileprivate static let zero = BigIntegerBuffer(count: 0)
    fileprivate static let one = BigIntegerBuffer(1)
    fileprivate static let minusOne = BigIntegerBuffer(-1)

    ///Always allocates a new region and initializes the count elements of the newly allocated region to zero.
    fileprivate init(count: Int) {
        assert(count >= 0)
        self.count = count
        if count != 0 {
            self.wordPtr = .allocate(capacity: count)
            self.wordPtr!.initialize(repeating: 0, count: count)
        }
        self.allocated = count
    }
    
    ///Always allocates a new region and copies the count elements from the buffer into the newly allocated region.
    fileprivate init(count: Int, buffer wordPtr: UnsafePointer<Word>?) {
        assert(count >= 0)
        assert(count == 0 || wordPtr != nil)
        self.count = count
        if count != 0 {
            self.wordPtr = .allocate(capacity: count)
            self.wordPtr!.initialize(from: wordPtr!, count: count)
        }
        self.allocated = count
    }
    
    fileprivate init(count: Int, buffer wordPtr: UnsafePointer<Word>?, negative: Bool) {
        assert(count >= 0)
        assert(count == 0 || wordPtr != nil)
        let minCount = BigIntegerBuffer.minimumRawCount(count: count, buffer: wordPtr)
        if minCount == 0 {
            self.count = 0
            self.wordPtr = nil
            self.allocated = 0
            return
        }
        let signWord = wordPtr![minCount - 1]
        if (signWord.isNegativeIfSigned && !negative)
            || (!signWord.isNegativeIfSigned && negative && !BigIntegerBuffer.isNegativeMinimumSigned(minCount, wordPtr: wordPtr)) {
            self.count = minCount + 1
            self.wordPtr = .allocate(capacity: minCount + 1)
            self.wordPtr!.initialize(from: wordPtr!, count: minCount)
            (self.wordPtr! + count).initialize(to: 0)
            self.allocated = count + 1
        } else {
            self.count = minCount
            self.wordPtr = .allocate(capacity: minCount)
            self.wordPtr!.initialize(from: wordPtr!, count: minCount)
            self.allocated = count
        }
        if negative {
            negateRaw()
        }
    }

    ///Initializer with taking the already allocated region.
    ///When allocated != 0, the ownership of the region is moved to
    ///the newly created instance. `allocated` needs to be excatly the same as actually allocated elements.
    ///Otherwise, when allocated == 0, the caller keeps the ownership of the allocated region and is responsible
    ///for:
    /// -- Keeping the region while the newly created instance is alive.
    /// -- Deallocating the region when it is never referenced.
    fileprivate init(count: Int, buffer wordPtr: UnsafeMutablePointer<Word>?, allocated: Int) {
        assert(count >= 0)
        assert(count == 0 || wordPtr != nil)
        assert(allocated >= 0 && allocated >= count)
        self.count = count
        self.wordPtr = wordPtr
        self.allocated = allocated
    }
    
    fileprivate convenience init(_ buff: BigIntegerBuffer) {
        self.init(count: buff.count, buffer: buff.wordPtr)
    }
    
    fileprivate convenience init() {
        self.init(count: 0)
    }
    
    fileprivate init(_ value: SignedWord) {
        if value == 0 {
            self.count = 0
            self.wordPtr = nil
            self.allocated = 0
        } else {
            self.count = 1
            self.wordPtr = .allocate(capacity: 1)
            self.wordPtr!.initialize(to: Word(bitPattern: value))
            self.allocated = 1
        }
    }
    
    private static func estimatedBits(for digits: Int, radix: Int = 10) -> Int {
        return Int(ceil(Double(digits) * log2(Double(radix))))
    }
    
    private static func estimatedDigits(for bits: Int, radix: Int = 10) -> Int {
        return Int(ceil(Double(bits) * log(2.0)/log(Double(radix))))
    }

    fileprivate init?<S: StringProtocol>(_ string: S, radix: Int, negative: Bool) {
        assert(2 <= radix && radix <= 36)
        if string == "0" {
            self.count = 0
            self.wordPtr = nil
            self.allocated = 0
            return
        }
        let estimatedBits = BigIntegerBuffer.estimatedBits(for: Int(string.count), radix: radix)
        let wordCount = (estimatedBits + BigIntegerBuffer.WordBits - 1)/BigIntegerBuffer.WordBits
        self.count = wordCount
        self.wordPtr = .allocate(capacity: wordCount)
        self.wordPtr!.initialize(repeating: 0, count: wordCount)
        self.allocated = wordCount
        for ch in string {
            guard let digitVal = ch.digitValue(radix: radix) else {
                return nil
            }
            multiplyRaw(Half(radix))
            addRaw(Word(digitVal))
        }
        if negative {
            self.negateRaw()
            if !mostSignificantWord.isNegativeIfSigned {
                extend(count: count+1, extendWith: Word.max)
            }
        } else {
            if mostSignificantWord.isNegativeIfSigned {
                extendZero(count: count+1)
            }
        }
    }

    deinit {
        if allocated != 0 {
            wordPtr!.deinitialize(count: allocated)
            wordPtr!.deallocate()
        }
    }
    
    //MARK: - reallocation

    private func extend(count newCount: Int, extendWith addedWord: Word) {
        //Little endian
        let newPtr = UnsafeMutablePointer<Word>.allocate(capacity: newCount)
        if count > 0 {
            newPtr.moveInitialize(from: wordPtr!, count: min(newCount, count))
        }
        if newCount > count {
            (newPtr + count).initialize(repeating: addedWord, count: newCount - count)
        }
        if allocated != 0 {
            wordPtr!.deinitialize(count: allocated)
            wordPtr!.deallocate()
        }
        allocated = newCount
        wordPtr = newPtr
        count = newCount
    }
    
    private func extendZero(count newCount: Int) {
        //Little endian
        if newCount <= count || newCount <= allocated {
            count = newCount
        } else {
            extend(count: newCount, extendWith: 0)
        }
    }
    
    private func extendSign(count newCount: Int) {
        //Little endian
        if newCount <= count || newCount <= allocated {
            count = newCount
        } else {
            extend(count: newCount, extendWith: signExtension)
        }
    }

    private var mostSignificantWord: Word {
        if count == 0 {
            return 0
        }
        //Little endian
        return wordPtr![count - 1]
    }
    
    private var signedWord: SignedWord {
        if count == 0 {
            return 0
        }
        //Little endian
        return SignedWord(bitPattern: wordPtr![count - 1])
    }
    
    public var isNegative: Bool {
        return signedWord < 0
    }
    
    private var signExtension: Word {
        return mostSignificantWord.signExtension
    }
    
    public var isZero: Bool {
        for i in 0..<count {
            if wordPtr![i] != 0 {return false}
        }
        return true
    }
    
    //MARK: - Equatable
    
    ///When applied to non-normalized BigIntegerBuffer's, may return false even if represented integer values are equal
    public static func == (lhs: BigIntegerBuffer, rhs: BigIntegerBuffer) -> Bool {
        if lhs.count != rhs.count {return false}
        for i in 0..<lhs.count {
            if lhs.wordPtr![i] != rhs.wordPtr![i] {return false}
        }
        return true
    }

    //MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        count.hash(into: &hasher)
        if count <= 8 {
            for i in 0..<count {
                wordPtr![i].hash(into: &hasher)
            }
        } else {
            for i in 0..<3 {
                wordPtr![i].hash(into: &hasher)
            }
            for i in count/2-1 ..< count/2+1 {
                wordPtr![i].hash(into: &hasher)
            }
            for i in count-3 ..< count {
                wordPtr![i].hash(into: &hasher)
            }
        }
    }
    
    //MARK: - Comparable support
    
    public enum ComparisonResult: Int8, Comparable {
        case less = -1
        case equal = 0
        case greater = 1
        
        public static func < (lhs: ComparisonResult, rhs: ComparisonResult) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        public static prefix func - (x: ComparisonResult) -> ComparisonResult {
            return ComparisonResult(rawValue: -x.rawValue)!
        }
    }
    
    ///Compare two signed big integers assuming both `count`s are minimized.
    fileprivate func compareSigned(to other: BigIntegerBuffer) -> ComparisonResult {
        if !self.isNegative && other.isNegative {return .greater}
        if self.isNegative && !other.isNegative {return .less}
        if isNegative {
            if self.count < other.count {
                return .greater
            } else if self.count > other.count {
                return .less
            }
            return compareUnsigned(to: other)
        } else {
            return compareUnsigned(to: other)
        }
    }
    
    ///Compare two unsigned big integers assuming both `count`s are minimized.
    private func compareUnsigned(to other: BigIntegerBuffer) -> ComparisonResult {
        if self.count > other.count {
            return .greater
        } else if self.count < other.count {
            return .less
        }
        //Little endian
        for i in (0..<count).reversed() {
            if self.wordPtr![i] > other.wordPtr![i] {
                return .greater
            } else if self.wordPtr![i] < other.wordPtr![i] {
                return .less
            }
        }
        return .equal
    }

    //MARK: - BinaryInteger support
    
    public var words: UnsafeBufferPointer<UInt> {
        if count == 0 {
            return UnsafeBufferPointer(start: nil, count: 0)
        }
        let uintCount = count * (MemoryLayout<Word>.size / MemoryLayout<UInt>.size)
        return wordPtr!.withMemoryRebound(to: UInt.self, capacity: uintCount) {uintPtr in
            return UnsafeBufferPointer(start: uintPtr, count: uintCount)
        }
    }
    
    public var trailingZeroBitCount: Int {
        var zeroBitCount = 0
        //Little endian
        for i in 0..<count {
            let word = self.wordPtr![i]
            if word == 0 {
                zeroBitCount += BigIntegerBuffer.WordBits
                break
            } else {
                zeroBitCount += word.trailingZeroBitCount
            }
        }
        return zeroBitCount
    }

    //MARK: - addition & subtraction
    
    private func addUnsignedWithoutExtension(_ buffer: BigIntegerBuffer) {
        var carry = false
        //Little endian
        for i in 0..<buffer.count {
            let (word1, overflow1) = wordPtr![i].addingReportingOverflow(buffer.wordPtr![i])
            if carry {
                let (word2, overflow2) = word1.addingReportingOverflow(1)
                wordPtr![i] = word2
                carry = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                carry = overflow1
            }
        }
        for i in buffer.count..<self.count {
            if carry {
                let (word, overflow) = wordPtr![i].addingReportingOverflow(1)
                wordPtr![i] = word
                carry = overflow
            }
        }
    }
    
    ///Mutating method.
    fileprivate func addSigned(_ buffer: BigIntegerBuffer) {
        extendSign(count: buffer.count + 1)
        let bufExtension = buffer.signExtension
        if bufExtension == 0 {
            addUnsignedWithoutExtension(buffer)
            return
        }
        var carry = false
        //Little endian
        for i in 0..<buffer.count {
            let (word1, overflow1) = wordPtr![i].addingReportingOverflow(buffer.wordPtr![i])
            if carry {
                let (word2, overflow2) = word1.addingReportingOverflow(1)
                wordPtr![i] = word2
                carry = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                carry = overflow1
            }
        }
        for i in buffer.count..<self.count {
            let (word1, overflow1) = wordPtr![i].addingReportingOverflow(bufExtension)
            if carry {
                let (word2, overflow2) = word1.addingReportingOverflow(1)
                wordPtr![i] = word2
                carry = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                carry = overflow1
            }
        }
    }

    ///Mutating method.
    private func subtractUnsignedWithoutExtension(_ buffer: BigIntegerBuffer) {
        var borrow = false
        //Little endian
        for i in 0..<buffer.count {
            let (word1, overflow1) = wordPtr![i].subtractingReportingOverflow(buffer.wordPtr![i])
            if borrow {
                let (word2, overflow2) = word1.subtractingReportingOverflow(1)
                wordPtr![i] = word2
                borrow = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                borrow = overflow1
            }
        }
        for i in buffer.count..<self.count {
            if borrow {
                let (word, overflow) = wordPtr![i].subtractingReportingOverflow(1)
                wordPtr![i] = word
                borrow = overflow
            }
        }
    }
    
    ///Mutating method.
    fileprivate func subtractSigned(_ buffer: BigIntegerBuffer) {
        extendSign(count: buffer.count + 1)
        let bufExtension = buffer.signExtension
        if bufExtension == 0 {
            subtractUnsignedWithoutExtension(buffer)
            return
        }
        var borrow = false
        //Little endian
        for i in 0..<buffer.count {
            let (word1, overflow1) = wordPtr![i].subtractingReportingOverflow(buffer.wordPtr![i])
            if borrow {
                let (word2, overflow2) = word1.subtractingReportingOverflow(1)
                wordPtr![i] = word2
                borrow = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                borrow = overflow1
            }
        }
        for i in buffer.count..<self.count {
            let (word1, overflow1) = wordPtr![i].subtractingReportingOverflow(bufExtension)
            if borrow {
                let (word2, overflow2) = word1.subtractingReportingOverflow(1)
                wordPtr![i] = word2
                borrow = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                borrow = overflow1
            }
        }
    }
    
    //MARK: - Bitwise operations
    
    ///Mutating method.
    fileprivate func bitwiseAndSigned(_ buffer: BigIntegerBuffer) {
        extendSign(count: buffer.count)
        //Little endian
        for i in 0..<buffer.count {
            self.wordPtr![i] &= buffer.wordPtr![i]
        }
        let extendWord = buffer.signExtension
        for i in buffer.count..<self.count {
            self.wordPtr![i] &= extendWord
        }
    }
    
    ///Mutating method.
    fileprivate func bitwiseOrSigned(_ buffer: BigIntegerBuffer) {
        extendSign(count: buffer.count)
        //Little endian
        for i in 0..<buffer.count {
            self.wordPtr![i] |= buffer.wordPtr![i]
        }
        let extendWord = buffer.signExtension
        for i in buffer.count..<self.count {
            self.wordPtr![i] |= extendWord
        }
    }
    
    ///Mutating method.
    fileprivate func bitwiseXorSigned(_ buffer: BigIntegerBuffer) {
        extendSign(count: buffer.count)
        //Little endian
        for i in 0..<buffer.count {
            self.wordPtr![i] ^= buffer.wordPtr![i]
        }
        let extendWord = buffer.signExtension
        for i in buffer.count..<self.count {
            self.wordPtr![i] ^= extendWord
        }
    }
    
    ///Mutating method.
    ///Does not return appropriate output for 0 and -1
    fileprivate func bitwiseNot() {
        for i in 0..<count {
            self.wordPtr![i] = ~self.wordPtr![i]
        }
    }

    //MARK: - Create BigInteger
    
    fileprivate func minimumCountForSigned() -> Int {
        return BigIntegerBuffer.minimumCountForSigned(count: count, buffer: wordPtr)
    }
    
    fileprivate static func minimumCountForSigned(count: Int, buffer wordPtr: UnsafePointer<Word>?) -> Int {
        if count == 0 {return 0}
        //Little endian
        let signExtension = wordPtr![count - 1].signExtension
        if signExtension == 0 {
            var currCount = count
            while currCount > 0 {
                if wordPtr![currCount - 1] != 0 {
                    return wordPtr![currCount - 1].isNegativeIfSigned ? currCount+1 : currCount
                }
                currCount -= 1
            }
            return 0
        } else {
            var currCount = count
            while currCount > 0 {
                if wordPtr![currCount - 1] != signExtension {
                    return wordPtr![currCount - 1].isNegativeIfSigned ? currCount : currCount+1
                }
                currCount -= 1
            }
            return 1
        }
    }
    
    private static func minimumRawCount(count: Int, buffer wordPtr: UnsafePointer<Word>?) -> Int {
        if count == 0 {return 0}
        //Little endian
        var currCount = count
        while currCount > 0 {
            if wordPtr![currCount - 1] != 0 {
                return currCount
            }
            currCount -= 1
        }
        return 0
    }

    ///Mutating method.
    fileprivate func normalize() {
        self.count = minimumCountForSigned()
    }

    //MARK: - Negation

    ///Checks if the content is the minimum singed value for the current `count`.
    private func isNegativeMinimumSigned() -> Bool {
        if !mostSignificantWord.isNegativeMinimumIfSigned {return false}
        //Little endian
        for i in 0..<count-1 {
            if wordPtr![i] != 0 {return false}
        }
        return true
    }

    private static func isNegativeMinimumSigned(_ count: Int, wordPtr: UnsafePointer<Word>?) -> Bool {
        if count == 0 {return false}
        //Little endian
        let signWord = wordPtr![count - 1]
        if signWord.isNegativeMinimumIfSigned {return false}
        for i in 0..<count-1 {
            if wordPtr![i] != 0 {return false}
        }
        return true
    }
    
    ///Mutating method.
    fileprivate func negateSigned() {
        if isNegativeMinimumSigned() {
            extendZero(count: count+1)
        } else {
            negateRaw()
        }
    }
    
    ///Mutating method.
    fileprivate func negateRaw() {
        var borrow = false
        //Little endian
        for i in 0..<self.count {
            let (word1, overflow1) = (0 as Word).subtractingReportingOverflow(wordPtr![i])
            if borrow {
                let (word2, overflow2) = word1.subtractingReportingOverflow(1)
                wordPtr![i] = word2
                borrow = overflow1 || overflow2
            } else {
                wordPtr![i] = word1
                borrow = overflow1
            }
        }
    }

    //MARK: - Multiplication
    
    ///Mutating method.
    private func multiplyRaw(_ multiplicand: BigIntegerBuffer, _ multiplier: BigIntegerBuffer) {
        assert(multiplicand.count > 0 && multiplier.count > 0)
        if allocated != 0 {
            wordPtr!.deinitialize(count: allocated)
            wordPtr!.deallocate()
        }
        count = multiplicand.count + multiplier.count
        wordPtr = .allocate(capacity: count)
        wordPtr?.initialize(repeating: 0, count: count)

        //Little endian
        self.wordPtr!.withMemoryRebound(to: Half.self, capacity: count * 2) {pd in
            var id = 0
            multiplier.wordPtr!.withMemoryRebound(to: Half.self, capacity: multiplier.count * 2) {pr in
                var ir = 0
                while ir < multiplier.count * 2 {
                    let v = Word(pr[ir])
                    ir += 1
                    let pd1 = pd + id
                    var id1 = 0
                    var upper: Word = 0
                    multiplicand.wordPtr!.withMemoryRebound(to: Half.self, capacity: multiplicand.count * 2) {ps in
                        var i = 0
                        upper = 0
                        while i < multiplicand.count * 2 {
                            let m = v * Word(ps[i])
                            i += 1
                            let a = Word(pd1[id1]) + upper + m
                            pd1[id1] = Half(truncatingIfNeeded: a)
                            id1 += 1
                            upper = a >> (BigIntegerBuffer.WordBits/2)
                        }
                    }
                    let a = Word(pd1[id1]) + upper
                    pd1[id1] = Half(truncatingIfNeeded: a)
                    id1 += 1
                    id += 1
                }
            }
        }
    }
    
    ///Mutating method.
    fileprivate func multiplySigned(_ multiplicand: BigIntegerBuffer, _ multiplier: BigIntegerBuffer) {
        multiplyRaw(multiplicand, multiplier)
        // Adjust for signed values.
        //Little endian
        if multiplicand.isNegative {
            subtractRaw(from: self.wordPtr! + multiplicand.count, multiplier)
        }
        if multiplier.isNegative {
            subtractRaw(from: self.wordPtr! + multiplier.count, multiplicand)
        }
    }
    
    // ResultLen must be greater than or equal to subtrahendLen .
    // ylen must be a multiple of size[sizeof(UW)].
    // result must be of the size as ylen.
    ///Mutating method.
    @discardableResult
    private func subtractRaw(from result: UnsafeMutablePointer<Word>, _ y: BigIntegerBuffer) -> Bool {
        assert(y.count > 0)

        var pr = result
        let py = y.wordPtr!
        var iy = 0
        //Little endian
        var borrow = false
        while iy < y.count {
            let (word1, overflow1) = pr.pointee.subtractingReportingOverflow(py[iy])
            iy += 1
            if borrow {
                let (a, overflow2) = word1.subtractingReportingOverflow(1)
                pr.pointee = a
                pr += 1
                borrow = overflow1 || overflow2
            } else {
                pr.pointee = word1
                pr += 1
                borrow = overflow1
            }
        }
        return borrow
    }
    
    ///Mutating method.
    @discardableResult
    private func multiplyRaw(_ multiplier: Half) -> Half {
        if count == 0 {return 0}
        return self.wordPtr!.withMemoryRebound(to: Half.self, capacity: count * 2) {halfPtr in
            var upper: Word = 0
            //Little endian
            for i in 0..<count*2 {
                let wordResult = Word(halfPtr[i]) * Word(multiplier) + upper
                halfPtr[i] = Half(truncatingIfNeeded: wordResult)
                upper = wordResult >> (BigIntegerBuffer.WordBits/2)
            }
            return Half(upper)
        }
    }
    
    ///Mutating method.
    @discardableResult
    private func addRaw(_ y: Word) -> Word {
        var carry: Word = y
        //Little endian
        for i in 0..<count {
            let (word1, overflow1) = wordPtr![i].addingReportingOverflow(carry)
            carry = overflow1 ? 1 : 0
            wordPtr![i] = word1
        }
        return carry
    }
    
    //MARK: - Conversion between Strings
    
    ///Mutating method.
    fileprivate func toStringAndDestructRaw(radix: Int = 10, negative: Bool = false) -> String {
        if isZero {return "0"}
        let estimatedDigits = BigIntegerBuffer.estimatedDigits(for: count * BigIntegerBuffer.WordBits, radix: radix)
        var chars: [UInt8] = Array(repeating: 0, count: estimatedDigits + 2)
        var lastIndex = chars.count - 1
        chars[lastIndex] = 0 //NUL terminator
        while !isZero {
            let rem = divideRaw(self.wordPtr!, self.count, by: Half(radix))
            lastIndex -= 1
            assert(lastIndex >= 0)
            chars[lastIndex] = Int(rem).toDigit(radix: radix, uppercase: true)
        }
        if negative {
            lastIndex -= 1
            assert(lastIndex >= 0)
            chars[lastIndex] = UInt8(ascii: "-")
        }
        return chars.withUnsafeBufferPointer {buffer in
            return String(cString: buffer.baseAddress! + lastIndex)
        }
    }
    
    //MARK: - Division
    
    ///Mutating method.
    @discardableResult
    private func divideRaw(_ wordPtr: UnsafeMutablePointer<Word>, _ count: Int, by divisor: Half) -> Half {
        return wordPtr.withMemoryRebound(to: Half.self, capacity: count * 2) {halfPtr in
            var rem: Word = 0
            //Little endian
            var index = count * 2 - 1
            while index >= 0 {
                let divident = (rem << (BigIntegerBuffer.WordBits/2)) + Word(halfPtr[index])
                let (q, r) = divident.quotientAndRemainder(dividingBy: Word(divisor))
                halfPtr[index] = Half(q)
                rem = r
                index -= 1
            }
            return Half(rem)
        }
    }

    ///Mutating method.
    @discardableResult
    private func divideRaw(_ wordPtr: UnsafeMutablePointer<Word>, _ count: Int, by divisor: Word) -> Word {
        var upper: Word = 0
        //Little endian
        var index = count - 1
        while index >= 0 {
            let (q, r) = divisor.dividingFullWidth((high: upper, low: wordPtr[index]))
            wordPtr[index] = q
            upper = r
            index -= 1
        }
        return upper
    }
    
    // Divisor must not be 0,
    // DividendLen - 4 must be greater than divisorLen.
    //:input (0: extra Word filled with 0)
    // self
    // |<-           count          ->|
    // |dividend                    |0|
    // divisor
    // |<-           count          ->|
    // |divisor         |
    //:output
    // self has 2 values, dividendLen - divisorLen for quotient, divisorLen for remainder.
    // |<-        dividendLen       ->|
    // |<- divisorLen ->|
    // |remainder       |quotient     |
    ///Division for two unsigned values
    ///Mutating method.
    @discardableResult
    private func divideRaw(by divisor: BigIntegerBuffer) -> UnsafeMutablePointer<Quarter> {
        //Little endian
        let newCount = max(self.count + 1, divisor.count + 1)
        extendZero(count: newCount)
        let dividend = UnsafeMutableRawPointer(self.wordPtr!)
        let dividendLen = self.count * MemoryLayout<Word>.size
        var pq = (dividend + dividendLen - MemoryLayout<Quarter>.size).assumingMemoryBound(to: Quarter.self)
        var divisorLen = divisor.count * MemoryLayout<Word>.size
        let pqend = (dividend + divisorLen).assumingMemoryBound(to: Quarter.self)
        let divisorPtr = UnsafeMutableRawPointer(divisor.wordPtr!)
        var ps = (divisorPtr + divisorLen).assumingMemoryBound(to: Quarter.self)
        while ps[-1] == 0 {
            ps -= 1
            divisorLen -= MemoryLayout<Quarter>.size
            pq += 1
        }
        // Divisor's most significant word. 2^16 <= dsw < 2^32
        let dsw = (Word(ps[-1]) << BigIntegerBuffer.QuarterBits)|Word(ps[-2])
        var pd = (dividend + dividendLen - MemoryLayout<Half>.size).assumingMemoryBound(to: Quarter.self)
        while pq > pqend {
            //Estimate partial quotient with 48-bit/32-bit division.
            let v = (Word(pd[0])<<BigIntegerBuffer.HalfBits)|(Word(pd[-1])<<BigIntegerBuffer.QuarterBits)|Word(pd[-2])
            var q = Half(truncatingIfNeeded: v/dsw)
            //Subtract (partial quotient)*divisor from (partial remainder)
            ps = divisorPtr.assumingMemoryBound(to: Quarter.self)
            var pd1 = (UnsafeMutableRawPointer(pd) - divisorLen).assumingMemoryBound(to: Quarter.self)
            var upper: Half = 0
            var borrow: Half = 0
            while ps < (divisorPtr + divisorLen).assumingMemoryBound(to: Quarter.self) {
                let m = Half(ps.pointee) &* q
                ps += 1
                let a = Half(pd1.pointee) &- (m & Half(Quarter.max)) &- upper &+ borrow
                pd1.pointee = Quarter(truncatingIfNeeded: a)
                pd1 += 1
                upper = (m >> BigIntegerBuffer.QuarterBits)
                borrow = Half(bitPattern: SignedHalf(bitPattern: a) >> BigIntegerBuffer.QuarterBits)
            }
            let a = Half(pd1.pointee) &- upper &+ borrow
            pd1.pointee = Quarter(truncatingIfNeeded: a)
            pd1 += 1
            //Estimated partial quotient was too big, adjust partial remainder and partial quotient
            if a != 0 {
                q -= 1
                ps = divisorPtr.assumingMemoryBound(to: Quarter.self)
                pd1 = (UnsafeMutableRawPointer(pd) - divisorLen).assumingMemoryBound(to: Quarter.self)
                var carry: Half = 0
                while UnsafeMutableRawPointer(ps) < divisorPtr + divisorLen {
                    let a = Half(pd1.pointee) &+ Half(ps.pointee) &+ carry
                    ps += 1
                    pd1.pointee = Quarter(truncatingIfNeeded: a)
                    pd1 += 1
                    carry = a >> (BigIntegerBuffer.QuarterBits)
                }
                let a = Half(pd1.pointee) + carry
                pd1.pointee = Quarter(truncatingIfNeeded: a)
                pd1 += 1
            }
            pd -= 1
            pq -= 1
            pq.pointee = Quarter(truncatingIfNeeded: q)
        }
        return pq
    }
    
    ///Mutating method.
    ///self must not be 0.
    ///divisor must not be 0.
    ///self needs to be greater than divisor.
    fileprivate func divideSigned(by divisor: BigIntegerBuffer) -> BigIntegerBuffer {
        if self.count == 1 {
            if divisor.count == 1 {
                let idividend = self.signedWord
                let idivisor = divisor.signedWord
                return BigIntegerBuffer(idividend / idivisor)
            } else {
                //Single word with maximum magnitude: 0x8000_0000_0000_0000
                //Double word with minimum magnitude: 0x0000_0000_0000_0000_8000_0000_0000_0000
                //Little endian
                if self.mostSignificantWord.isNegativeMinimumIfSigned
                    && divisor.count == 2 && divisor.mostSignificantWord == 0
                    && divisor.wordPtr![0].isNegativeMinimumIfSigned {
                    return .minusOne
                } else {
                    // abs(self) < abs(divisor)
                    return .zero
                }
            }
        }
        let dividendNegative = self.isNegative
        if dividendNegative {
            self.negateRaw()
        }
        let divisorNegative = divisor.isNegative
        if divisorNegative {
            divisor.negateRaw()
        }
        var resultNegative = dividendNegative
        if divisorNegative {resultNegative = !resultNegative}
        if divisor.count == 1 {
            divideRaw(self.wordPtr!, self.count, by: divisor.wordPtr![0])
            return BigIntegerBuffer(count: self.count, buffer: self.wordPtr!, negative: resultNegative)
        } else {
            divideRaw(by: divisor)
            return BigIntegerBuffer(count: self.count - divisor.count, buffer: self.wordPtr! + divisor.count, negative: resultNegative)
        }
    }
    ///Mutating method.
    fileprivate func quotientAndRemainderSigned(by divisor: BigIntegerBuffer) -> (BigIntegerBuffer, BigIntegerBuffer) {
        if self.count == 1 {
            if divisor.count == 1 {
                let idividend = self.signedWord
                let idivisor = divisor.signedWord
                return (BigIntegerBuffer(idividend / idivisor), BigIntegerBuffer(idividend % idivisor))
            } else {
                //Little endian
                //Single word with maximum magnitude: 0x8000_0000_0000_0000
                //Double word with minimum magnitude: 0x0000_0000_0000_0000_8000_0000_0000_0000
                if self.mostSignificantWord.isNegativeMinimumIfSigned
                    && divisor.count == 2 && divisor.mostSignificantWord == 0
                    && divisor.wordPtr![0].isNegativeMinimumIfSigned {
                    return (.minusOne, .zero)
                } else {
                    // abs(self) < abs(divisor)
                    return (.zero, self)
                }
            }
        }
        let dividendNegative = self.isNegative
        if dividendNegative {
            self.negateRaw()
        }
        let divisorNegative = divisor.isNegative
        if divisorNegative {
            divisor.negateRaw()
        }
        var resultNegative = dividendNegative
        if divisorNegative {resultNegative = !resultNegative}
        let remainderNegative = dividendNegative
        if divisor.count == 1 {
            let uremainder = divideRaw(self.wordPtr!, self.count, by: divisor.wordPtr![0])
            var remainder = SignedWord(bitPattern: uremainder)
            if remainderNegative {
                remainder = -remainder
            }
            return (BigIntegerBuffer(count: self.count, buffer: self.wordPtr!, negative: resultNegative), BigIntegerBuffer(remainder))
        } else {
            divideRaw(by: divisor)
            return (BigIntegerBuffer(count: self.count - divisor.count, buffer: self.wordPtr! + divisor.count, negative: resultNegative),
                    BigIntegerBuffer(count: divisor.count, buffer: self.wordPtr!, negative: remainderNegative))
        }
    }

    ///Mutating method.
    ///self must not be 0.
    ///divisor must not be 0.
    ///self needs to be greater than divisor.
    fileprivate func remainderSigned(by divisor: BigIntegerBuffer) -> BigIntegerBuffer {
        if self.count == 1 {
            if divisor.count == 1 {
                let idividend = self.signedWord
                let idivisor = divisor.signedWord
                return BigIntegerBuffer(idividend % idivisor)
            } else {
                //Little endian
                //Single word with maximum magnitude: 0x8000_0000_0000_0000
                //Double word with minimum magnitude: 0x0000_0000_0000_0000_8000_0000_0000_0000
                if self.mostSignificantWord.isNegativeMinimumIfSigned
                    && divisor.count == 2 && divisor.mostSignificantWord == 0
                    && divisor.wordPtr![0].isNegativeMinimumIfSigned {
                    return .zero
                } else {
                    // abs(self) < abs(divisor)
                    return self
                }
            }
        }
        let dividendNegative = self.isNegative
        if dividendNegative {
            self.negateRaw()
        }
        let divisorNegative = divisor.isNegative
        if divisorNegative {
            divisor.negateRaw()
        }
        let remainderNegative = dividendNegative
        if divisor.count == 1 {
            let uremainder = divideRaw(self.wordPtr!, self.count, by: divisor.wordPtr![0])
            var remainder = SignedWord(bitPattern: uremainder)
            if remainderNegative {
                remainder = -remainder
            }
            return BigIntegerBuffer(remainder)
        } else {
            divideRaw(by: divisor)
            return BigIntegerBuffer(count: divisor.count, buffer: self.wordPtr!, negative: remainderNegative)
        }
    }
    
    ///Mutating method.
    fileprivate func shiftRightSigned(bits: UInt) -> BigIntegerBuffer {
        if self.count == 0 {return .zero}
        if self.count == 1 {return BigIntegerBuffer(self.signedWord >> bits)}
        if bits >= self.count * BigIntegerBuffer.WordBits {
            if self.isNegative {
                return .minusOne
            } else {
                return .zero
            }
        }
        let shiftWords = Int(bits / UInt(BigIntegerBuffer.WordBits))
        var newCount = self.count - shiftWords
        let shiftBits = Int(bits % UInt(BigIntegerBuffer.WordBits))
        if shiftBits == 0 {
            return BigIntegerBuffer(count: newCount, buffer: self.wordPtr!+shiftWords)
        }
        //Little endian
        var srcPtr = self.wordPtr! + self.count - 1
        var highWord: BigIntegerBuffer.Word
        if self.isNegative {
            let leadingOnes = (~self.mostSignificantWord).leadingZeroBitCount
            if leadingOnes + shiftBits <= BigIntegerBuffer.WordBits {
                highWord = .max &<< (BigIntegerBuffer.WordBits - shiftBits)
            } else if newCount == 1 {
                return .minusOne
            } else {
                newCount -= 1
                highWord = srcPtr.pointee &<< (BigIntegerBuffer.WordBits - shiftBits)
                srcPtr -= 1
            }
        } else {
            let leadingZeros = self.mostSignificantWord.leadingZeroBitCount
            if leadingZeros + shiftBits <= BigIntegerBuffer.WordBits {
                highWord = 0
            } else if newCount == 1 {
                return .zero
            } else {
                newCount -= 1
                highWord = srcPtr.pointee &<< (BigIntegerBuffer.WordBits - shiftBits)
                srcPtr -= 1
            }
        }
        let result = BigIntegerBuffer()
        result.extend(count: newCount, extendWith: 0)
        var destPtr = result.wordPtr! + newCount - 1
        while newCount > 0 {
            assert(destPtr >= result.wordPtr! && destPtr < result.wordPtr! + result.count)
            destPtr.pointee = (srcPtr.pointee >> shiftBits) | highWord
            highWord = srcPtr.pointee &<< (BigIntegerBuffer.WordBits - shiftBits)
            destPtr -= 1
            srcPtr -= 1
            newCount -= 1
        }
        return result
    }
    
    ///Mutating method.
    fileprivate func shiftLeftSigned(bits: UInt) -> BigIntegerBuffer {
        if self.isZero {return .zero}
        let shiftWords = Int(bits / UInt(BigIntegerBuffer.WordBits))
        var newCount = self.count + shiftWords
        let shiftBits = Int(bits % UInt(BigIntegerBuffer.WordBits))
        //Little endian
        var srcPtr = self.wordPtr!
        let result = BigIntegerBuffer()
        if shiftBits == 0 {
            result.extend(count: newCount, extendWith: 0)
            let destPtr = result.wordPtr! + shiftWords
            destPtr.assign(from: srcPtr, count: self.count)
            return result
        }
        var lowWord: BigIntegerBuffer.Word = 0
        let signExtension: Word
        if self.isNegative {
            signExtension = .max
            let leadingOnes = (~self.mostSignificantWord).leadingZeroBitCount
            if leadingOnes <= shiftBits {
                newCount += 1
            }
        } else {
            signExtension = 0
            let leadingZeros = self.mostSignificantWord.leadingZeroBitCount
            if leadingZeros <= shiftBits {
                newCount += 1
            }
        }
        result.extend(count: newCount, extendWith: 0)
        var destPtr = result.wordPtr! + shiftWords
        newCount -= shiftWords
        while newCount > 0 {
            assert(destPtr >= result.wordPtr! && destPtr < result.wordPtr! + result.count)
            if srcPtr < self.wordPtr! + self.count {
                destPtr.pointee = (srcPtr.pointee << shiftBits) | lowWord
                lowWord = srcPtr.pointee &>> (BigIntegerBuffer.WordBits - shiftBits)
                destPtr += 1
                srcPtr += 1
            } else {
                destPtr.pointee = (signExtension << shiftBits) | lowWord
            }
            newCount -= 1
        }
        return result
    }
    
    ///Mutating method.
    fileprivate func shiftLeftSigned(signedBits bits: Int) -> BigIntegerBuffer {
        if bits < 0 {
            return shiftRightSigned(bits: bits.magnitude)
        } else {
            return shiftLeftSigned(bits: bits.magnitude)
        }
    }
}

extension BigIntegerBuffer.Word {
    fileprivate var signExtension: BigIntegerBuffer.Word {
        return isNegativeIfSigned ? BigIntegerBuffer.Word.max: 0
    }
    fileprivate var isNegativeIfSigned: Bool {
        return self > BigIntegerBuffer.Word.max/2
    }
    fileprivate var isNegativeMinimumIfSigned: Bool {
        return self == BigIntegerBuffer.Word.max/2 + 1
    }
}

fileprivate extension Character {
    func digitValue(radix: Int = 10) -> UInt32? {
        if self.unicodeScalars.count != 1 {
            return nil
        }
        let ch = self.unicodeScalars.first!
        if "0" <= ch && ch <= "9" {
            let value = ch.value - ("0" as UnicodeScalar).value
            if Int(value) < radix {
                return value
            } else {
                return nil
            }
        } else if "A" <= ch && ch <= "F" {
            let value = ch.value - ("A" as UnicodeScalar).value + 10
            if Int(value) < radix {
                return value
            } else {
                return nil
            }
        } else if "a" <= ch && ch <= "f" {
            let value = ch.value - ("a" as UnicodeScalar).value + 10
            if Int(value) < radix {
                return value
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

fileprivate extension Int {
    func toDigit(radix: Int = 10, uppercase: Bool = true) -> UInt8 {
        assert( 0 <= self && self < radix)
        if self < 10 {
            return UInt8(ascii: "0") + UInt8(self)
        } else if uppercase {
            return UInt8(ascii: "A") + UInt8(self - 10)
        } else {
            return UInt8(ascii: "a") + UInt8(self - 10)
        }
    }
}

public struct BigInteger: SignedInteger, LosslessStringConvertible {
    public static let zero = BigInteger()
    public static let one = BigInteger(1)
    public static let minusOne = BigInteger(-1)
    
    ///Always contains normalized representation. (i.e. `count` is minimized.)
    ///Allocated region held in `wordPtr` may have some extra words than `count`.
    private var buffer: BigIntegerBuffer
    
    private init() {
        self.buffer = BigIntegerBuffer.zero
    }
    
    private init(buffer: BigIntegerBuffer) {
        assert(buffer.count == buffer.minimumCountForSigned())
        self.buffer = buffer
    }

    ///A little bit more efficient way to check if zero, when normalized.
    public var isZero: Bool {
        return buffer.count == 0
    }
    
    private var isNegative: Bool {
        return buffer.isNegative
    }
    
    private var count: Int {
        return buffer.count
    }

    //MARK: - Equatable (<Hashable<BinaryInteger<SignedInteger)
    
    public static func == (lhs: BigInteger, rhs: BigInteger) -> Bool {
        return lhs.buffer == rhs.buffer
    }

    public func hash(into hasher: inout Hasher) {
        buffer.hash(into: &hasher)
    }
    
    //MARK: - Numeric
    public init?<T>(exactly source: T) where T : BinaryInteger {
        self.init(source)
    }

    public var magnitude: BigInteger {
        if isNegative {
            return -self
        }
        return self
    }
    
    public static func +(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {return lhs}
        if lhs.isZero {return rhs}
        let buff = BigIntegerBuffer(lhs.buffer)
        buff.addSigned(rhs.buffer)
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public static func +=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs + rhs
    }
    
    public static func -(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {return lhs}
        let buff = BigIntegerBuffer(lhs.buffer)
        buff.subtractSigned(rhs.buffer)
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public static func -=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs - rhs
    }
    
    public static func *(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if lhs.isZero || rhs.isZero {return .zero}
        if lhs == 1 {return rhs}
        if rhs == 1 {return lhs}
        let buff = BigIntegerBuffer()
        buff.multiplySigned(lhs.buffer, rhs.buffer)
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public static func *=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs * rhs
    }
    
    //MARK: - Comparable (<Numeric<(BinaryInteger, SingedNumeric)<SignedInteger)
    
    public static func < (lhs: BigInteger, rhs: BigInteger) -> Bool {
        return lhs.buffer.compareSigned(to: rhs.buffer) < .equal
    }
    
    public static func <= (lhs: BigInteger, rhs: BigInteger) -> Bool {
        return lhs.buffer.compareSigned(to: rhs.buffer) <= .equal
    }
    
    public static func > (lhs: BigInteger, rhs: BigInteger) -> Bool {
        return lhs.buffer.compareSigned(to: rhs.buffer) > .equal
    }
    
    public static func >= (lhs: BigInteger, rhs: BigInteger) -> Bool {
        return lhs.buffer.compareSigned(to: rhs.buffer) >= .equal
    }
    
    //MARK: - ExpressibleByIntegerLiteral (<Numeric<(BinaryInteger, SingedNumeric)<SignedInteger)
    
    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    //MARK: - SignedNumeric (<SignedInteger)
    
    public static prefix func -(arg: BigInteger) -> BigInteger {
        if arg.isZero {return arg}
        let buff = BigIntegerBuffer(arg.buffer)
        buff.negateSigned()
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public mutating func negate() {
        if self.isZero {return}
        let buff = BigIntegerBuffer(self.buffer)
        buff.negateSigned()
        buff.normalize()
        assert(buffer.count == buffer.minimumCountForSigned())
        self.buffer = buff
    }

    //MARK: - BinaryInteger (<SignedInteger)
    
    public static var isSigned: Bool { return true }
    
    public init?<T>(exactly source: T) where T : BinaryFloatingPoint {
        if source.isNaN || source.isInfinite || source.rounded() != source {
            return nil
        }
        self.init(source)
    }
    
    public init<T>(_ _source: T) where T : BinaryFloatingPoint {
        if _source.isNaN || _source.isInfinite {
            fatalError("NaN or inifinity cannot be represented in BigInteger")
        }
        let source = _source.rounded()
        if source == 0.0 {
            self = .zero
        }
        let negative = source.sign == .minus
        //We cannot handle BinaryFloatingPoint types with exponent larget than Int
        let exponent = Int(source.exponentBitPattern)
        let bias = (1 << (T.exponentBitCount - 1)) - 1
        //We cannot handle BinaryFloatingPoint types with significand bits larget than BigIntegerBuffer.Word
        //We ignore cases of non-canonical values, as they are rounded to 0 when converting to an Integer
        var mantissa = BigIntegerBuffer.Word(source.significandBitPattern) | (1 << T.significandBitCount)
        let buff = BigIntegerBuffer(count: 1, buffer: &mantissa, negative: negative)
        let bits = exponent - bias - T.significandBitCount
        self.buffer = buff.shiftLeftSigned(signedBits: bits)
        assert(buffer.count == buffer.minimumCountForSigned())
    }

    public init<T>(_ source: T) where T : BinaryInteger {
        let size = MemoryLayout<T>.size
        let wordSize = MemoryLayout<BigIntegerBuffer.Word>.size
        var wordCount = (size+wordSize-1) / wordSize
        var buffer: [BigIntegerBuffer.Word] = Array(repeating: 0, count: wordCount)
        if T.isSigned {
            buffer.withUnsafeMutableBytes {bytes in
                var uintPtr = bytes.baseAddress!.assumingMemoryBound(to: UInt.self)
                let uintPtrEnd = (bytes.baseAddress! + bytes.count).assumingMemoryBound(to: UInt.self)
                var lastSourceWord: UInt = 0
                for sourceWord in source.words {
                    assert(uintPtr >= bytes.baseAddress!.assumingMemoryBound(to: UInt.self) && uintPtr < uintPtrEnd)
                    uintPtr.pointee = sourceWord
                    lastSourceWord = sourceWord
                    uintPtr += 1
                }
                // extend sign
                if Int(bitPattern: lastSourceWord) < 0 {
                    while uintPtr < uintPtrEnd {
                        assert(uintPtr >= bytes.baseAddress!.assumingMemoryBound(to: UInt.self) && uintPtr < uintPtrEnd)
                        uintPtr.pointee = UInt.max
                        uintPtr += 1
                    }
                }
            }
            wordCount = BigIntegerBuffer.minimumCountForSigned(count: wordCount, buffer: buffer)
            self.buffer = BigIntegerBuffer(count: wordCount, buffer: buffer)
            assert(self.buffer.count == self.buffer.minimumCountForSigned())
        } else {
            buffer.withUnsafeMutableBytes {bytes in
                var uintPtr = bytes.baseAddress!.assumingMemoryBound(to: UInt.self)
                for sourceWord in source.words {
                    assert(uintPtr >= bytes.baseAddress!.assumingMemoryBound(to: UInt.self) && uintPtr < (bytes.baseAddress! + bytes.count).assumingMemoryBound(to: UInt.self))
                    uintPtr.pointee = sourceWord
                    uintPtr += 1
                }
            }
            wordCount = BigIntegerBuffer.minimumCountForSigned(count: wordCount, buffer: buffer)
            self.buffer = BigIntegerBuffer(count: wordCount, buffer: buffer, negative: false)
            assert(self.buffer.count == self.buffer.minimumCountForSigned())
        }
    }
    
    public init<T>(truncatingIfNeeded source: T) where T : BinaryInteger {
        self.init(source)
    }
    
    public init<T>(clamping source: T) where T : BinaryInteger {
        self.init(source)
    }
    
    public var words: UnsafeBufferPointer<UInt> {
        return buffer.words
    }
    
    public var bitWidth: Int {
        return buffer.count * BigIntegerBuffer.WordBits
    }
    
    public var trailingZeroBitCount: Int {
        return buffer.trailingZeroBitCount
    }

    public static func /(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {fatalError("Division by zero")}
        if lhs.isZero {return .zero}
        if rhs == 1 {return lhs}
        if rhs == -1 {return -lhs}
        let dividend = BigIntegerBuffer(lhs.buffer)
        let divisor = BigIntegerBuffer(rhs.buffer)
        let quotient = dividend.divideSigned(by: divisor)
        quotient.normalize()
        return BigInteger(buffer: quotient)
    }
    
    public static func /=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs / rhs
    }
    
    public static func %(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {fatalError("Division by zero")}
        if lhs.isZero {return .zero}
        if rhs == 1 {return .zero}
        if rhs == -1 {return .zero}
        let dividend = BigIntegerBuffer(lhs.buffer)
        let divisor = BigIntegerBuffer(rhs.buffer)
        let remainder = dividend.remainderSigned(by: divisor)
        remainder.normalize()
        return BigInteger(buffer: remainder)
    }
    
    public static func %=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs % rhs
    }
    
    prefix public static func ~(x: BigInteger) -> BigInteger {
        if x.isZero {return .minusOne}
        if x == -1 {return .zero}
        let buff = BigIntegerBuffer(x.buffer)
        buff.bitwiseNot()
        return BigInteger(buffer: buff)
    }
    
    public static func &(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {return .zero}
        if lhs.isZero {return .zero}
        let buff = BigIntegerBuffer(lhs.buffer)
        buff.bitwiseAndSigned(rhs.buffer)
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public static func &=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs & rhs
    }
    
    public static func |(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {return lhs}
        if lhs.isZero {return rhs}
        let buff = BigIntegerBuffer(lhs.buffer)
        buff.bitwiseOrSigned(rhs.buffer)
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public static func |=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs | rhs
    }
    
    public static func ^(lhs: BigInteger, rhs: BigInteger) -> BigInteger {
        if rhs.isZero {return lhs}
        if lhs.isZero {return rhs}
        let buff = BigIntegerBuffer(lhs.buffer)
        buff.bitwiseXorSigned(rhs.buffer)
        buff.normalize()
        return BigInteger(buffer: buff)
    }
    
    public static func ^=(lhs: inout BigInteger, rhs: BigInteger) {
        lhs = lhs ^ rhs
    }
    
    public static func >> <RHS>(lhs: BigInteger, rhs: RHS) -> BigInteger where RHS : BinaryInteger {
        if rhs == 0 {return lhs}
        guard let bits = Int(exactly: rhs) else {
            if rhs < 0 {
                fatalError("Shift count for '>>' too big")
            } else {
                return lhs.isNegative ? .minusOne : .zero
            }
        }
        if rhs < 0 {
            return BigInteger(buffer: lhs.buffer.shiftLeftSigned(bits: bits.magnitude))
        } else {
            return BigInteger(buffer: lhs.buffer.shiftRightSigned(bits: bits.magnitude))
        }
    }
    
    public static func >>=<RHS>(lhs: inout BigInteger, rhs: RHS) where RHS : BinaryInteger {
        lhs = lhs >> rhs
    }
    
    public static func << <RHS>(lhs: BigInteger, rhs: RHS) -> BigInteger where RHS : BinaryInteger {
        if rhs == 0 {return lhs}
        guard let bits = Int(exactly: rhs) else {
            if rhs >= 0 {
                fatalError("Shift count for '<<' too big")
            } else {
                return lhs.isNegative ? .minusOne : .zero
            }
        }
        if rhs < 0 {
            return BigInteger(buffer: lhs.buffer.shiftRightSigned(bits: bits.magnitude))
        } else {
            return BigInteger(buffer: lhs.buffer.shiftLeftSigned(bits: bits.magnitude))
        }
    }
    
    public static func <<=<RHS>(lhs: inout BigInteger, rhs: RHS) where RHS : BinaryInteger {
        lhs = lhs << rhs
    }
    
    public func quotientAndRemainder(dividingBy rhs: BigInteger) -> (quotient: BigInteger, remainder: BigInteger) {
        if rhs.isZero {fatalError("Division by zero")}
        if self.isZero {return (.zero, .zero)}
        if rhs == 1 {return (self, .zero)}
        if rhs == -1 {return (-self, .zero)}
        let dividend = BigIntegerBuffer(self.buffer)
        let divisor = BigIntegerBuffer(rhs.buffer)
        let (q, r) = dividend.quotientAndRemainderSigned(by: divisor)
        return (BigInteger(buffer: q), BigInteger(buffer: r))
    }
    
    public func signum() -> BigInteger {
        if self.isZero {
            return .zero
        } else if self.isNegative {
            return .minusOne
        } else {
            return .one
        }
    }
    
    //MARK: - CustomStringConvertible (<BinaryInteger<SignedInteger)
    
    public var description: String {
        return self.toString()
    }
    
    //MARK: - Strideable (<BinaryInteger<SignedInteger)
    
    public func distance(to other: BigInteger) -> BigInteger {
        return other - self
    }
    
    public func advanced(by n: BigInteger) -> BigInteger {
        return self + n
    }
    
    //MARK: - LosslessStringConvertible

    public init?(_ string: String) {
        self.init(string, radix: 10)
    }

    //MARK: -

    public init?<S: StringProtocol>(_ string: S, radix: Int = 10) {
        if string.starts(with: "-") {
            guard let buffer = BigIntegerBuffer(string.dropFirst(), radix: radix, negative: true) else {
                return nil
            }
            assert(buffer.count == buffer.minimumCountForSigned())
            self.buffer = buffer
        } else {
            guard let buffer = BigIntegerBuffer(string, radix: radix, negative: false) else {
                return nil
            }
            assert(buffer.count == buffer.minimumCountForSigned())
            self.buffer = buffer
        }
    }

    public func toString(radix: Int = 10) -> String {
        let buff = BigIntegerBuffer(self.buffer)
        let negative = buff.isNegative
        if negative {
            buff.negateRaw()
        }
        return buff.toStringAndDestructRaw(radix: radix, negative: negative)
    }
}

