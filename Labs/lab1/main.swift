import Foundation

// MARK: - SERIAL

func serialMultiplyMatrix(matrixA: [Int], matrixB: [Int]) -> [Int] {
    var result: [Int] = Array(repeating: 0, count: matrixSize * matrixSize)

    for indexStr in 0..<matrixSize {
        
        for indexCol in 0..<matrixSize {
            
            var sum = 0
            for index in 0..<matrixSize {
                sum += matrixA[indexStr * matrixSize + index] * matrixB[index * matrixSize + indexCol]
            }
            
            result[indexStr * matrixSize + indexCol] = sum
        }
    }
    
    return result
}

// MARK: - ASYNC

func asyncFastestMultiplyMatrix(matrixA: [Int], matrixB: [Int]) -> [Int] {
    var result: [Int] = Array(repeating: 0, count: matrixSize * matrixSize)
    DispatchQueue.concurrentPerform(iterations: matrixSize) { indexStr in

        DispatchQueue.concurrentPerform(iterations: matrixSize) { indexCol in

            var sum = 0
            DispatchQueue.concurrentPerform(iterations: matrixSize) { index in
                sum += matrixA[indexStr * matrixSize + index] * matrixB[index * matrixSize + indexCol]
            }

            result[indexStr * matrixSize + indexCol] = sum
        }
    }
    return result
}

func asyncMultiplyMatrix(matrixA: [Int], matrixB: [Int]) -> [Int] {
    var result: [Int] = Array(repeating: 0, count: matrixSize * matrixSize)
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 100

    for indexStr in 0..<matrixSize {
        queue.addOperation {
            for indexCol in 0..<matrixSize {
                queue.addOperation {
                    var sum = 0
                    for index in 0..<matrixSize {
                        sum += matrixA[indexStr * matrixSize + index] * matrixB[index * matrixSize + indexCol]
                    }
                    result[indexStr * matrixSize + indexCol] = sum
                }
            }
        }
    }
    queue.waitUntilAllOperationsAreFinished()

    return result
}

// MARK: - OTHER

func print(matrix: [Int]) {
    for indexStr in 0..<matrixSize {
        for indexCol in 0..<matrixSize {
            print(matrix[indexStr * matrixSize + indexCol], terminator: " ")
        }
        print()
    }
}

func measure(process: (() -> Void)) {
    let startTime = CFAbsoluteTimeGetCurrent()
    process()
    let endTime = CFAbsoluteTimeGetCurrent()
    print(endTime - startTime)
}

// MARK: - MAIN

let matrixSize: Int = 1000

var matrixA: [Int] = (1...matrixSize * matrixSize).map { _ in
    Int.random(in: 1...100)
}

var matrixB: [Int] = (1...matrixSize * matrixSize).map { _ in
    Int.random(in: 1...100)
}

var result1: [Int] = []
var result2: [Int] = []

measure {
    result1 = serialMultiplyMatrix(matrixA: matrixA, matrixB: matrixB)
}

measure {
    result2 = asyncMultiplyMatrix(matrixA: matrixA, matrixB: matrixB)
}

print(result1 == result2)
