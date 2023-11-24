import Foundation

extension Array {
    func roundedIndex(of index: Int) -> Int {
        let position: Int
        if index < 0 {
            position = count + index % count
        } else if index >= count {
            position = index % count
        } else {
            position = index
        }
        
        return position
    }
    
    subscript(safe index: Int) -> Element {
        get {
            let position = roundedIndex(of: index)
            return self[position]
        }
        set(newValue) {
            let position = roundedIndex(of: index)
            self[position] = newValue
        }
    }
}

extension TimeInterval {

    static var eatingTime: TimeInterval {
        Double(Int.random(in: 1...10)) / 10
    }
    
    static var thinkingTime: TimeInterval {
        Double(Int.random(in: 1...10)) / 10
    }
    
    static var takingForkTime: TimeInterval {
        Double(Int.random(in: 1...5)) / 10
    }
}

extension CFAbsoluteTime {
    
    static var currentTime: CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }
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
    
    let ID: Int
    
    private var currentState: PhilosopherState = .none
    private var activityThread: Thread? = nil
    private var isActivated = false
    
    private let delegate: ForkDelegate
    
    var tookLeftFork: Bool = false
    var tookRightFork: Bool = false
    
    init(ID: Int, delegate: ForkDelegate) {
        self.ID = ID
        self.delegate = delegate
    }
    
    func startActivity() {
        isActivated = true
        activityThread = Thread { [weak self] in
            guard let self else {
                return
            }
            
            while isActivated {
                activity()
            }
        }
        activityThread?.start()
    }
    
    func endActivity() {
        isActivated = false
        activityThread?.cancel()
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
            tookLeftFork = false
            tookRightFork = false
            delegate.putForks(for: ID)
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

protocol ForkDelegate {
    func getLeftFork(for philosopherID: Int) -> Bool
    func getRightFork(for philosopherID: Int) -> Bool
    func putForks(for philosopherID: Int)
}

class Table {
    
    let places: Int
    var isForkExist: [Bool]
    var philosophers: [Philosopher] = []
    private var lock = NSLock()
    
    init(places: Int) {
        self.places = places
        self.isForkExist = Array(repeating: true, count: places)
    }
    
    private func addPhilosophers() {
        for i in 0..<places {
            philosophers.append(.init(ID: i, delegate: self))
        }
    }
    
    func start() {
        addPhilosophers()
        philosophers.forEach { philosopher in
            philosopher.startActivity()
        }
    }
    
    func printState() {
        philosophers.forEach { philosopher in
            philosopher.printState()
        }
        print()
    }
    
    func end() {
        philosophers.forEach { philosopher in
            philosopher.endActivity()
        }
    }
}

extension Table: ForkDelegate {
    func getLeftFork(for philosopherID: Int) -> Bool {
        lock.withLock {
            let exist = isForkExist[safe: philosopherID - 1]
            isForkExist[safe: philosopherID - 1] = false
            return exist
        }
    }
    
    func getRightFork(for philosopherID: Int) -> Bool {
        lock.withLock {
            let exist = isForkExist[safe: philosopherID]
            isForkExist[safe: philosopherID] = false
            return exist
        }
    }
    
    func putForks(for philosopherID: Int) {
        lock.withLock {
            isForkExist[safe: philosopherID - 1] = true
            isForkExist[safe: philosopherID] = true
        }
    }
}

let table = Table(places: 5)
table.start()

let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    table.printState()
}
timer.fire()

RunLoop.main.run()
