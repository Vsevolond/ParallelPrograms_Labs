import Foundation

extension TimeInterval {

    static var randomTime: TimeInterval {
        Double(Int.random(in: 1...10)) / 10
    }
}

extension CFAbsoluteTime {
    
    static var currentTime: CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }
}

enum PhilosopherState {

    case thinking(startTime: CFAbsoluteTime, duration: TimeInterval)
    case takeLeftFork
    case takeRightFork
    case eating(startTime: CFAbsoluteTime, duration: TimeInterval)
    case putForks
    case none
}

class Philosopher {
    
    private let ID: Int
    
    private var currentState: PhilosopherState = .none
    private var activityThread: Thread? = nil
    private var lock = NSLock()

    var leftNeighbor: Philosopher? = nil
    var rightNeighbor: Philosopher? = nil
    
    var hasLeftFork: Bool = true
    var hasRightFork: Bool = true
    
    init(ID: Int) {
        self.ID = ID
    }
    
    func startActivity() {
        activityThread = Thread { [weak self] in
            self?.activity()
            RunLoop.current.run()
        }
        activityThread?.start()
    }
    
    func endActivity() {
        activityThread?.cancel()
        currentState = .none
    }
    
    func printState() {
        switch currentState {
        case .thinking(_, _):
            print("Philosopher \(ID): thinking")
        case .takeLeftFork:
            print("Philosopher \(ID): took left fork")
        case .takeRightFork:
            print("Philosopher \(ID): took right fork")
        case .eating(_, _):
            print("Philosopher \(ID): eating")
        case .putForks:
            print("Philosopher \(ID): put forks")
        case .none:
            print("Philosopher \(ID): do nothing")
        }
    }
    
    private func hasAppetit() -> Bool {
        Bool.random()
    }
    
    private func activity() {
        switch currentState {

        case .thinking(let startTime, let duration):
            if .currentTime - startTime >= duration, hasLeftFork, hasRightFork {
                lock.withLock {
                    if Bool.random() {
                        currentState = .takeLeftFork
                        leftNeighbor?.hasRightFork = false
                    } else {
                        currentState = .takeRightFork
                        rightNeighbor?.hasLeftFork = false
                    }
                }

            } else {
                currentState = .thinking(startTime: .currentTime, duration: .randomTime)
            }
            
        case .takeLeftFork:
            if hasRightFork {
                if let rightNeighbor, !rightNeighbor.hasLeftFork {
                    currentState = .eating(startTime: .currentTime, duration: .randomTime)
                } else {
                    lock.withLock {
                        currentState = .takeRightFork
                        rightNeighbor?.hasLeftFork = false
                    }
                }

            } else {
                leftNeighbor?.hasRightFork = true
                currentState = .thinking(startTime: .currentTime, duration: .randomTime)
            }

        case .takeRightFork:
            if hasLeftFork {
                if let leftNeighbor, !leftNeighbor.hasRightFork {
                    currentState = .eating(startTime: .currentTime, duration: .randomTime)
                } else {
                    lock.withLock {
                        currentState = .takeLeftFork
                        leftNeighbor?.hasRightFork = false
                    }
                }

            } else {
                rightNeighbor?.hasLeftFork = true
                currentState = .thinking(startTime: .currentTime, duration: .randomTime)
            }

        case .eating(let startTime, let duration):
            if .currentTime - startTime >= duration {
                currentState = .putForks
            }

        case .putForks:
            lock.withLock {
                leftNeighbor?.hasRightFork = true
                rightNeighbor?.hasLeftFork = true
            }
            currentState = .thinking(startTime: .currentTime, duration: .randomTime)

        case .none:
            if hasLeftFork, hasRightFork, hasAppetit() {
                lock.withLock {
                    if Bool.random() {
                        currentState = .takeLeftFork
                        leftNeighbor?.hasRightFork = false
                    } else {
                        currentState = .takeRightFork
                        rightNeighbor?.hasLeftFork = false
                    }
                }

            } else {
                currentState = .thinking(startTime: .currentTime, duration: .randomTime)
            }
        }
    }
}

func makePhilosophers(count: Int) -> [Philosopher] {
    var philosophers = [Philosopher]()
    
    for i in 1...count {
        philosophers.append(.init(ID: i))
    }
    
    for i in 1..<count - 1 {
        philosophers[i].leftNeighbor = philosophers[i - 1]
        philosophers[i].rightNeighbor = philosophers[i + 1]
    }
    
    philosophers[0].leftNeighbor = philosophers[count - 1]
    philosophers[count - 1].rightNeighbor = philosophers[0]
    
    return philosophers
}

let philosophers = makePhilosophers(count: 5)

let start = CFAbsoluteTime.currentTime

var isStarted = false

for philosopher in philosophers {
    philosopher.startActivity()
}

let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    philosophers.forEach { philosopher in
        philosopher.printState()
    }
    print()
}
timer.fire()

RunLoop.main.run()

philosophers.forEach { philosopher in
    philosopher.endActivity()
}
timer.invalidate()
