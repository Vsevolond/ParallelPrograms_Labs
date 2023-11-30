import Foundation

// MARK: - Extensions

extension TimeInterval {

    static var eatingTime: TimeInterval {
        Double(Int.random(in: 10...15)) / 10
    }
    
    static var thinkingTime: TimeInterval {
        Double(Int.random(in: 10...15)) / 10
    }
    
    static var takingForkTime: TimeInterval {
        Double(Int.random(in: 5...10)) / 10
    }
}

extension CFAbsoluteTime {
    
    static var currentTime: CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }
}

// MARK: - Philosopher

protocol ForkDelegate {

    func getLeftFork(for philosopherID: Int) -> Bool
    func getRightFork(for philosopherID: Int) -> Bool
    func putForks(for philosopherID: Int)
}

enum PhilosopherState {

    case thinking(startTime: CFAbsoluteTime, duration: TimeInterval)
    case takingLeftFork(startTime: CFAbsoluteTime, duration: TimeInterval)
    case takingRightFork(startTime: CFAbsoluteTime, duration: TimeInterval)
    case eating(startTime: CFAbsoluteTime, duration: TimeInterval)
    case putForks
    case none
}

class Philosopher {

    // MARK: - Private Properties

    private let ID: Int
    private var currentState: PhilosopherState = .none
    private var isActivated = false
    
    private let delegate: ForkDelegate
    
    private var tookLeftFork: Bool = false
    private var tookRightFork: Bool = false
    
    // MARK: - Initializers
    
    init(ID: Int, delegate: ForkDelegate) {
        self.ID = ID
        self.delegate = delegate
    }
    
    // MARK: - Internal Methods

    func startActivity(on queue: OperationQueue) {
        isActivated = true
        queue.addOperation { [weak self] in
            guard let self else {
                return
            }
            
            while isActivated, !queue.isSuspended {
                activity()
            }
        }
    }
    
    func endActivity() {
        isActivated = false
        currentState = .none
    }
    
    func printState() {
        switch currentState {
        case .thinking(_, _):
            print("Philosopher \(ID): thinking 🤔")
        case .takingLeftFork(_, _):
            print("Philosopher \(ID): taking left fork ✋")
        case .takingRightFork(_, _):
            print("Philosopher \(ID): taking right fork 🤚")
        case .eating(_, _):
            print("Philosopher \(ID): eating 🍲")
        case .putForks:
            print("Philosopher \(ID): put forks 🙌")
        case .none:
            print("Philosopher \(ID): do nothing 😑")
        }
    }
    
    // MARK: - Private Methods
    
    private func hasAppetit() -> Bool {
        Bool.random()
    }
    
    private func activity() {
        switch currentState {

        case .thinking(let startTime, let duration):
            if .currentTime - startTime >= duration {
                if Bool.random(), delegate.getLeftFork(for: ID) {
                    currentState = .takingLeftFork(startTime: .currentTime, duration: .takingForkTime)
                } else if delegate.getRightFork(for: ID) {
                    currentState = .takingRightFork(startTime: .currentTime, duration: .takingForkTime)
                } else {
                    currentState = .thinking(startTime: .currentTime, duration: .thinkingTime)
                }
            }

        case .takingLeftFork(let startTime, let duration):
            if .currentTime - startTime >= duration {
                tookLeftFork = true
                
                if tookRightFork {
                    currentState = .eating(startTime: .currentTime, duration: .eatingTime)
                } else if delegate.getRightFork(for: ID) {
                    currentState = .takingRightFork(startTime: .currentTime, duration: .takingForkTime)
                } else {
                    currentState = .putForks
                }
            }

        case .takingRightFork(let startTime, let duration):
            if .currentTime - startTime >= duration {
                tookRightFork = true
                
                if tookLeftFork {
                    currentState = .eating(startTime: .currentTime, duration: .eatingTime)
                } else if delegate.getLeftFork(for: ID) {
                    currentState = .takingLeftFork(startTime: .currentTime, duration: .takingForkTime)
                } else {
                    currentState = .putForks
                }
            }

        case .eating(let startTime, let duration):
            if .currentTime - startTime >= duration {
                currentState = .putForks
            }

        case .putForks:
            delegate.putForks(for: ID)
            tookLeftFork = false
            tookRightFork = false
            currentState = .thinking(startTime: .currentTime, duration: .thinkingTime)

        case .none:
            if hasAppetit() {
                if Bool.random(), delegate.getLeftFork(for: ID) {
                    currentState = .takingLeftFork(startTime: .currentTime, duration: .takingForkTime)
                } else if delegate.getRightFork(for: ID) {
                    currentState = .takingRightFork(startTime: .currentTime, duration: .takingForkTime)
                } else {
                    currentState = .thinking(startTime: .currentTime, duration: .thinkingTime)
                }

            } else {
                currentState = .thinking(startTime: .currentTime, duration: .thinkingTime)
            }
        }
    }
}

// MARK: - Table

class Table {
    
    // MARK: - Private Properties

    private let places: Int
    private var forks: [Bool]
    private var philosophers: [Philosopher] = []
    
    private let philosophersQueue = OperationQueue()
    private let lock = NSLock()
    
    // MARK: - Initializers

    init(places: Int) {
        self.places = places
        self.forks = .init(repeating: true, count: places)
        self.philosophersQueue.maxConcurrentOperationCount = places
    }
    
    // MARK: - Internal Methods

    func printState() {
        philosophersQueue.isSuspended = true
        philosophersQueue.waitUntilAllOperationsAreFinished()
        for philosopher in philosophers {
            philosopher.printState()
        }
        print()
        philosophersQueue.isSuspended = false
        for philosopher in philosophers {
            philosopher.startActivity(on: philosophersQueue)
        }
    }
    
    func start() {
        addPhilosophers()
        for philosopher in philosophers {
            philosopher.startActivity(on: philosophersQueue)
        }
    }
    
    func end() {
        for philosopher in philosophers {
            philosopher.endActivity()
        }
    }
    
    // MARK: - Private Methods

    private func addPhilosophers() {
        for i in 0..<places {
            philosophers.append(.init(ID: i, delegate: self))
        }
    }
}

extension Table: ForkDelegate {

    // MARK: - Protocol Methods

    func getLeftFork(for philosopherID: Int) -> Bool {
        lock.lock()
        let isExist = forks[philosopherID]
        if isExist {
            forks[philosopherID] = false
        }
        lock.unlock()

        return isExist
    }

    func getRightFork(for philosopherID: Int) -> Bool {
        let position = (philosopherID + 1) % philosophers.count

        lock.lock()
        let isExist = forks[position]
        if isExist {
            forks[position] = false
        }
        lock.unlock()

        return isExist
    }

    func putForks(for philosopherID: Int) {
        let position = (philosopherID + 1) % philosophers.count

        lock.withLock {
            forks[philosopherID] = true
            forks[position] = true
        }
    }
}

// MARK: - MAIN

let table = Table(places: 5)
table.start()

let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
    table.printState()
}

RunLoop.main.run()
