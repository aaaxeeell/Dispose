import Carbon

/// Global keyboard shortcuts via Carbon's RegisterEventHotKey, which works
/// in any app and needs no extra permission.
final class HotKeyCenter {
    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue().actions[hotKey.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// `keyCode` is a kVK_* virtual key (a physical key position);
    /// `modifiers` combines Carbon's controlKey/optionKey/shiftKey/cmdKey.
    @discardableResult
    func register(_ keyCode: Int, _ modifiers: Int, _ action: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4453_5053) /* "DSPS" */, id: id)
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                  GetApplicationEventTarget(), 0, &ref) == noErr, let ref
        else {
            NSLog("Dispose: shortcut key %d mods %d is taken by another app", keyCode, modifiers)
            return false
        }
        refs.append(ref)
        actions[id] = action
        return true
    }
}
