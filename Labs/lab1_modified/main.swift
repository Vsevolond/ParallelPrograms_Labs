import Foundation

// Алгоритм Штрассена

func asyncMultiplyMatrix(matrixA: [Int], matrixB: [Int], size: Int) -> [Int] {
    var result: [Int] = Array(repeating: 0, count: matrixSize * matrixSize)
    let group = DispatchGroup()

    for indexStr in 0..<size {
        
        group.enter()
        
        DispatchQueue.global().async {
            for indexCol in 0..<size {
                
                var sum = 0
                for index in 0..<size {
                    sum += matrixA[indexStr * size + index] * matrixB[index * size + indexCol]
                }
                
                result[indexStr * size + indexCol] = sum
            }
            
            group.leave()
        }
    }
    
    group.wait()
    
    return result
}

func serialMultiplyMatrix(matrixA: [Int], matrixB: [Int], size: Int) -> [Int] {
    var result: [Int] = Array(repeating: 0, count: size * size)

    for indexStr in 0..<size {
        
        for indexCol in 0..<size {
            
            var sum = 0
            for index in 0..<size {
                sum += matrixA[indexStr * size + index] * matrixB[index * size + indexCol]
            }
            
            result[indexStr * size + indexCol] = sum
        }
    }
    
    return result
}

func strassenMultiplyMatrix(matrixA: [Int], matrixB: [Int], size: Int) -> [Int] {
    if size <= 128 {
        return asyncMultiplyMatrix(matrixA: matrixA, matrixB: matrixB, size: size)
    }

    let (a11, a12, a21, a22) = splitMatrix(matrix: matrixA, size: size)
    let (b11, b12, b21, b22) = splitMatrix(matrix: matrixB, size: size)
    
    let p1 = strassenMultiplyMatrix(
        matrixA: additionOfMatrix(matrix1: a11, matrix2: a22),
        matrixB: additionOfMatrix(matrix1: b11, matrix2: b22),
        size: size / 2
    )
    let p2 = strassenMultiplyMatrix(
        matrixA: additionOfMatrix(matrix1: a21, matrix2: a22),
        matrixB: b11,
        size: size / 2
    )
    let p3 = strassenMultiplyMatrix(
        matrixA: a11,
        matrixB: substractionOfMatrix(matrix1: b12, matrix2: b22),
        size: size / 2
    )
    let p4 = strassenMultiplyMatrix(
        matrixA: a22,
        matrixB: substractionOfMatrix(matrix1: b21, matrix2: b11),
        size: size / 2
    )
    let p5 = strassenMultiplyMatrix(
        matrixA: additionOfMatrix(matrix1: a11, matrix2: a12),
        matrixB: b22,
         size: size / 2
    )
    let p6 = strassenMultiplyMatrix(
        matrixA: substractionOfMatrix(matrix1: a21, matrix2: a11),
        matrixB: additionOfMatrix(matrix1: b11, matrix2: b12),
        size: size / 2
    )
    let p7 = strassenMultiplyMatrix(
        matrixA: substractionOfMatrix(matrix1: a12, matrix2: a22),
        matrixB: additionOfMatrix(matrix1: b21, matrix2: b22),
        size: size / 2
    )
    
    let c11 = additionOfMatrix(
        matrix1: additionOfMatrix(matrix1: p1, matrix2: p7),
        matrix2: substractionOfMatrix(matrix1: p4, matrix2: p5)
    )
    let c12 = additionOfMatrix(matrix1: p3, matrix2: p5)
    let c21 = additionOfMatrix(matrix1: p2, matrix2: p4)
    let c22 = additionOfMatrix(
        matrix1: substractionOfMatrix(matrix1: p1, matrix2: p2),
        matrix2: additionOfMatrix(matrix1: p3, matrix2: p6)
    )
    
    return concatMatrix(matrix11: c11, matrix12: c12, matrix21: c21, matrix22: c22, size: size / 2)
}

func concatMatrix(matrix11: [Int], matrix12: [Int], matrix21: [Int], matrix22: [Int], size: Int) -> [Int] {
    let matrixSize = size * 2
    var matrix = Array(repeating: 0, count: size * size * 4)
    
    DispatchQueue.concurrentPerform(iterations: size) { strNum in
        DispatchQueue.concurrentPerform(iterations: size) { colNum in
            matrix[strNum * matrixSize + colNum] = matrix11[strNum * size + colNum]
            matrix[strNum * matrixSize + colNum + size] = matrix12[strNum * size + colNum]
            matrix[(strNum + size) * matrixSize + colNum] = matrix21[strNum * size + colNum]
            matrix[(strNum + size) * matrixSize + (colNum + size)] = matrix22[strNum * size + colNum]
        }
    }
    
    return matrix
}

func substractionOfMatrix(matrix1: [Int], matrix2: [Int]) -> [Int] {
    let result = (0..<matrix1.count).map { index in
        matrix1[index] - matrix2[index]
    }
    return result
}

func additionOfMatrix(matrix1: [Int], matrix2: [Int]) -> [Int] {
    let result = (0..<matrix1.count).map { index in
        matrix1[index] + matrix2[index]
    }
    return result
}

func expandMatrix(matrix: [Int], size: Int) -> [Int] {
    let newSize = getNewDimension(last: size)
    var newMatrix = Array(repeating: 0, count: newSize * newSize)
    (0..<size).forEach { index in
        newMatrix[index * newSize..<(index * newSize + size)] = matrix[index * size..<size * (index + 1)]
    }
    return newMatrix
}

func getNewDimension(last: Int) -> Int {
    var size = last - 1
    
    while size & (size - 1) != 0 {
        size = size & (size - 1)
    }
    
    return size << 1
}

func splitMatrix(matrix: [Int], size: Int) -> ([Int], [Int], [Int], [Int]) {
    let half = size / 2
    var splitted = (
        m11: Array(repeating: 0, count: half * half),
        m12: Array(repeating: 0, count: half * half),
        m21: Array(repeating: 0, count: half * half),
        m22: Array(repeating: 0, count: half * half)
    )
    DispatchQueue.concurrentPerform(iterations: half) { strNum in
        DispatchQueue.concurrentPerform(iterations: half) { colNum in
            splitted.m11[strNum * half + colNum] = matrix[strNum * size + colNum]
            splitted.m12[strNum * half + colNum] = matrix[strNum * size + colNum + half]
            splitted.m21[strNum * half + colNum] = matrix[(strNum + half) * size + colNum]
            splitted.m22[strNum * half + colNum] = matrix[(strNum + half) * size + (colNum + half)]
        }
    }
    
    return splitted
}

func print(matrix: [Int], size: Int) {
    for indexStr in 0..<size {
        for indexCol in 0..<size {
            print(matrix[indexStr * size + indexCol], terminator: " ")
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


let matrixSize: Int = 400

var matrixA: [Int] = (1...matrixSize * matrixSize).map { _ in
    Int.random(in: 1...100)
}

var matrixB: [Int] = (1...matrixSize * matrixSize).map { _ in
    Int.random(in: 1...100)
}

var resultAsync: [Int] = []
var resultStrassen: [Int] = []

print(getNewDimension(last: matrixSize))

measure {
    resultAsync = asyncMultiplyMatrix(matrixA: matrixA, matrixB: matrixB, size: matrixSize)
}
measure {
    resultStrassen = strassenMultiplyMatrix(
        matrixA: expandMatrix(matrix: matrixA, size: matrixSize),
        matrixB: expandMatrix(matrix: matrixB, size: matrixSize),
        size: getNewDimension(last: matrixSize)
    )
}


print(resultAsync == resultStrassen.filter({ $0 != 0 }))

