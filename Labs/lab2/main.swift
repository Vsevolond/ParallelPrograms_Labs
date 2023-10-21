import Foundation
import Combine

class Queue<Element> {
    var items: [Element] = []
    
    init() {}
    
    func enqueue(_ item: Element) {
        items.append(item)
    }

    func dequeue() -> Element? {
        guard items.count > 0 else {
            return nil
        }
        return items.removeFirst()
    }
}

class ThreadControl {
    private var activeThreads = Set<Thread>()
    private var threadsQueue = Queue<Thread>()
    var maxCountOfThreads: Int
    
    init(maxCountOfThreads: Int) {
        self.maxCountOfThreads = maxCountOfThreads
        
        Thread.detachNewThread { [weak self] in
            guard let self else {
                return
            }
            for thread in self.activeThreads {
                if thread.isFinished {
                    self.activeThreads.remove(thread)
                }
            }
            (self.activeThreads.count..<self.maxCountOfThreads).forEach { _ in
                guard let thread = self.threadsQueue.dequeue() else {
                    return
                }
                self.activeThreads.insert(thread)
            }
            RunLoop.current.run()
        }
    }
    
    func detachNewThread(block: @escaping () -> Void) {
        let thread = Thread {
            block()
        }
        thread.start()
        threadsQueue.enqueue(thread)
    }
    
    func waitUntilAllThreadsFinished() {
        while !activeThreads.isEmpty {}
    }
}

func iterationSLAUSolution(matrixA: [[Double]], vectorB: [Double], size: Int) -> [Double] {
    var vectorX: [Double] = Array(repeating: 0, count: size)
    var tau: Double = 0.1 / Double(size)
    let eps: Double = 0.00001
    var flag = false
    
    while !flag {
        let value1 = checkValueOf(matrixA: matrixA, vectorB: vectorB, vectorX: vectorX)
        if value1 < eps {
            flag = true
        } else {
            let newVectorX = nextVectorOf(vector: vectorX, matrixA: matrixA, vectorB: vectorB, tau: tau)
            let value2 = checkValueOf(matrixA: matrixA, vectorB: vectorB, vectorX: newVectorX)
            if value2 > value1 {
                tau = -tau
            } else {
                vectorX = newVectorX
            }
        }
    }
    
    return vectorX
}

//func asyncIterationSLAUSolution(matrixA: [[Double]], vectorB: [Double], size: Int, split count: Int) -> [Double] {
//    let operationQueue = OperationQueue()
//    operationQueue.maxConcurrentOperationCount = size //size / count + size % count == 0 ? 0 : 1
//    var vectorX: [Double] = Array(repeating: 0, count: size)
//    var tau: Double = 0.1 / Double(size)
//    let eps: Double = 0.00001
//    var flag = false
//
//    while !flag {
//        let checkValue = checkValueOf(matrixA: matrixA, vectorB: vectorB, vectorX: vectorX)
//        if checkValue < eps {
//            flag = true
//        } else {
//            var newVectorX = vectorX
//            for i in stride(from: 0, to: size, by: count) {
//                operationQueue.addOperation {
//                    let localTau = tau
//                    let subMatrixA = Array(matrixA[i..<i+count])
//                    let coefOfNewVectorX = nextVectorOf(vector: vectorX, matrixA: subMatrixA, vectorB: vectorB, tau: localTau)
//                    (i..<i+count).forEach { index in
//                        newVectorX[index] = coefOfNewVectorX[index - i]
//                    }
//                }
//            }
//
//            operationQueue.waitUntilAllOperationsAreFinished()
//            let newCheckValue = checkValueOf(matrixA: matrixA, vectorB: vectorB, vectorX: newVectorX)
//            if newCheckValue > checkValue {
//                tau = -tau
//            } else {
//                vectorX = newVectorX
//            }
//        }
//    }
//    return vectorX
//}

func asyncIterationSLAUSolution(matrixA: [[Double]], vectorB: [Double], size: Int, split count: Int) -> [Double] {
    let control = ThreadControl(maxCountOfThreads: 100)
    var vectorX: [Double] = Array(repeating: 0, count: size)
    var tau: Double = 0.1 / Double(size)
    let eps: Double = 0.00001
    var flag = false

    while !flag {
        let checkValue = checkValueOf(matrixA: matrixA, vectorB: vectorB, vectorX: vectorX)
        if checkValue < eps {
            flag = true
        } else {
            var newVectorX = vectorX
            for i in stride(from: 0, to: size, by: count) {
                control.detachNewThread {
                    let localTau = tau
                    let subMatrixA = Array(matrixA[i..<i+count])
                    let coefOfNewVectorX = nextVectorOf(vector: vectorX, matrixA: subMatrixA, vectorB: vectorB, tau: localTau)
                    (i..<i+count).forEach { index in
                        newVectorX[index] = coefOfNewVectorX[index - i]
                    }
                }
            }
            control.waitUntilAllThreadsFinished()

            let newCheckValue = checkValueOf(matrixA: matrixA, vectorB: vectorB, vectorX: newVectorX)
            if newCheckValue > checkValue {
                tau = -tau
            } else {
                vectorX = newVectorX
            }
        }
    }
    return vectorX
}

func nextVectorOf(vector: [Double], matrixA: [[Double]], vectorB: [Double], tau: Double) -> [Double] {
    return substractionOf(
        vector1: vector,
        vector2: multiplyOf(
            vector: substractionOf(
                vector1: multiplyOf(matrix: matrixA, vector: vector),
                vector2: vectorB
            ),
            multiplier: tau
        )
    )
}

func checkValueOf(matrixA: [[Double]], vectorB: [Double], vectorX: [Double]) -> Double {
    let value1 = moduleOf(
        vector: substractionOf(
            vector1: multiplyOf(matrix: matrixA, vector: vectorX),
            vector2: vectorB
        )
    )
    let value2 = moduleOf(vector: vectorB)
    
    return value1 / value2
}

func multiplyOf(vector: [Double], multiplier: Double) -> [Double] {
    return vector.map { item in
        item * multiplier
    }
}

func substractionOf(vector1: [Double], vector2: [Double]) -> [Double] {
    return (0..<vector1.count).map { index in
        vector1[index] - vector2[index]
    }
}

func multiplyOf(matrix: [[Double]], vector: [Double]) -> [Double] {
    var result: [Double] = Array(repeating: 0, count: vector.count)
    (0..<matrix.count).forEach { index in
        result[index] = multiplyOf(vector1: matrix[index], vector2: vector)
    }
    
    return result
}

func multiplyOf(vector1: [Double], vector2: [Double]) -> Double {
    var result: Double = 0
    (0..<vector1.count).forEach { index in
        result += vector1[index] * vector2[index]
    }
    
    return result
}

func moduleOf(vector: [Double]) -> Double {
    var result: Double = 0
    vector.forEach { item in
        result += item * item
    }
    return sqrt(result)
}

func print(matrix: [[Double]], size: Int) {
    matrix.forEach { str in
        str.forEach { item in
            print(item, terminator: " ")
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

let count: Int = 16
let matrixA: [[Double]] = (0..<count).map { index1 in
    return (0..<count).map { index2 in
        index1 == index2 ? 2.0 : 1.0
    }
}

let vectorB: [Double] = Array(repeating: Double(count + 1), count: count)

var resultSerial: [Double] = []
var resultAsync: [Double] = []
//measure {
//    resultSerial = iterationSLAUSolution(matrixA: matrixA, vectorB: vectorB, size: count)
//}
measure {
    resultAsync = asyncIterationSLAUSolution(matrixA: matrixA, vectorB: vectorB, size: count, split: 8)
}

print(resultSerial == resultAsync)
