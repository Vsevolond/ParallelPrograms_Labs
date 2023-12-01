import Foundation

// MARK: - Extensions

extension TimeInterval {

    static var eatingTime: TimeInterval {
        Double.random(in: 3...4)
    }
    
    static var thinkingTime: TimeInterval {
        Double.random(in: 2...3)
    }
    
    static var takingForkTime: TimeInterval {
        Double.random(in: 1...2)
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
    func putLeftFork(for philosopherID: Int)
    func putRightFork(for philosopherID: Int)
    func putForks(for philosopherID: Int)
}

enum ForkType {

    case left
    case right
    case both
}

enum PhilosopherState {

    case thinking(startTime: CFAbsoluteTime, duration: TimeInterval)
    case takingLeftFork(startTime: CFAbsoluteTime, duration: TimeInterval)
    case takingRightFork(startTime: CFAbsoluteTime, duration: TimeInterval)
    case eating(startTime: CFAbsoluteTime, duration: TimeInterval)
    case putForks(type: ForkType)
    case none
    
    func string(withEmoji: Bool) -> String {
        switch self {
        case .thinking(_, _): return "thinking \(withEmoji ? "🤔" : "")"
        case .takingLeftFork(_, _): return "taking left fork \(withEmoji ? "✋" : "")"
        case .takingRightFork(_, _): return "taking right fork \(withEmoji ? "🤚" : "")"
        case .eating(_, _): return "eating \(withEmoji ? "🍲" : "")"
        case .putForks(_): return "put forks \(withEmoji ? "🙌" : "")"
        case .none: return "do nothing \(withEmoji ? "😑" : "")"
        }
    }
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

    func printState(withEmoji: Bool) {
        print("Philosopher \(ID): \(currentState.string(withEmoji: withEmoji))")
    }
    
    func getState(withEmoji: Bool) -> String {
        return currentState.string(withEmoji: withEmoji)
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
                    currentState = .putForks(type: .left)
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
                    currentState = .putForks(type: .right)
                }
            }

        case .eating(let startTime, let duration):
            if .currentTime - startTime >= duration {
                currentState = .putForks(type: .both)
            }

        case .putForks(let type):
            switch type {

            case .left:
                delegate.putLeftFork(for: ID)
                tookLeftFork = false

            case .right:
                delegate.putRightFork(for: ID)
                tookRightFork = false

            case .both:
                delegate.putForks(for: ID)
                tookLeftFork = false
                tookRightFork = false
            }

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

    func printState(format: LogFormat) {
        philosophersQueue.isSuspended = true
        philosophersQueue.waitUntilAllOperationsAreFinished()
        Logger.shared.log(philosophers: philosophers, format: format)
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
        defer { lock.unlock() }

        let isExist = forks[philosopherID]
        if isExist {
            forks[philosopherID] = false
        }

        return isExist
    }

    func getRightFork(for philosopherID: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let position = (philosopherID + 1) % philosophers.count
        let isExist = forks[position]
        if isExist {
            forks[position] = false
        }

        return isExist
    }
    
    func putLeftFork(for philosopherID: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        forks[philosopherID] = true
    }
    
    func putRightFork(for philosopherID: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let position = (philosopherID + 1) % philosophers.count
        forks[position] = true
    }

    func putForks(for philosopherID: Int) {
        lock.lock()
        defer { lock.unlock() }

        let position = (philosopherID + 1) % philosophers.count
        forks[philosopherID] = true
        forks[position] = true
    }
}

// MARK: - Logger

enum LogFormat {
    
    case list
    case table
}

class Logger {
    
    static let shared = Logger()
    
    func log(philosophers: [Philosopher], format: LogFormat) {
        switch format {
        case .list:
            for philosopher in philosophers {
                philosopher.printState(withEmoji: true)
            }
            print()

        case .table:
            let states = philosophers.map { $0.getState(withEmoji: false) }
            var result = ""
            for state in states {
                result += "| " + state + " "
            }
            print(result)
            print()
        }
    }
}

// MARK: - MAIN

let table = Table(places: 5)
table.start()

let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
    table.printState(format: .list)
}

RunLoop.main.run()
