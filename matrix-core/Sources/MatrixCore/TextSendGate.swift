// the server's queue remains asynchronous and continues sending while this gate is free.
actor TextSendGate {
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if busy { await withCheckedContinuation { waiting.append($0) } }
        else { busy = true }
    }

    func release() {
        if waiting.isEmpty { busy = false }
        else { waiting.removeFirst().resume() }
    }
}
