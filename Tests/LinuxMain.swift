import XCTest
import Glibc
@testable import WebSocketClientTests

// http://stackoverflow.com/questions/24026510/how-do-i-shuffle-an-array-in-swift
#if swift(>=3.2)
    extension MutableCollection {
        mutating func shuffle() {
            let c = count
            guard c > 1 else { return }

            srand(UInt32(time(nil)))
            for (firstUnshuffled, unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
                let d: IndexDistance = numericCast(random() % numericCast(unshuffledCount))
                guard d != 0 else { continue }
                let i = index(firstUnshuffled, offsetBy: d)
                swapAt(firstUnshuffled, i)
            }
        }
    }
#else
    extension MutableCollection where Indices.Iterator.Element == Index {
        mutating func shuffle() {
            let c = count
            guard c > 1 else { return }

            srand(UInt32(time(nil)))
            for (firstUnshuffled, unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
                let d: IndexDistance = numericCast(random() % numericCast(unshuffledCount))
                guard d != 0 else { continue }
                let i = index(firstUnshuffled, offsetBy: d)
                swap(&self[firstUnshuffled], &self[i])
            }
        }
    }
#endif

extension Sequence {
    func shuffled() -> [Iterator.Element] {
        var result = Array(self)
        result.shuffle()
        return result
    }
}

XCTMain([
    testCase(BasicTests.allTests.shuffled()),
    testCase(ComplexTests.allTests.shuffled()),
    testCase(ProtocolError.allTests.shuffled()),
    testCase(ConnectionCleanUptests.allTests.shuffled()),
    testCase(DelegateTests.allTests.shuffled()),
].shuffled())
