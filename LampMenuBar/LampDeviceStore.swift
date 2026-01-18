import Foundation

struct LampDeviceStore {
    static let shared = LampDeviceStore()

    private let idKey = "LampDeviceUUID"
    private let nameKey = "LampDeviceName"
    private let powerKey = "LampPowerState"
    private let hueKey = "LampColorH"
    private let saturationKey = "LampColorS"
    private let valueKey = "LampColorV"

    func save(id: UUID, name: String) {
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
        UserDefaults.standard.set(name, forKey: nameKey)
    }

    func loadID() -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: idKey) else {
            return nil
        }
        return UUID(uuidString: value)
    }

    func loadName() -> String? {
        return UserDefaults.standard.string(forKey: nameKey)
    }

    func requireID() throws -> UUID {
        guard let id = loadID() else {
            throw LampError.deviceNotSelected
        }
        return id
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: powerKey)
        UserDefaults.standard.removeObject(forKey: hueKey)
        UserDefaults.standard.removeObject(forKey: saturationKey)
        UserDefaults.standard.removeObject(forKey: valueKey)
    }

    func savePowerState(isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: powerKey)
    }

    func loadPowerState() -> Bool? {
        guard UserDefaults.standard.object(forKey: powerKey) != nil else {
            return nil
        }
        return UserDefaults.standard.bool(forKey: powerKey)
    }

    func saveHSV(h: Int, s: Int, v: Int) {
        UserDefaults.standard.set(h, forKey: hueKey)
        UserDefaults.standard.set(s, forKey: saturationKey)
        UserDefaults.standard.set(v, forKey: valueKey)
    }

    func loadHSV() -> (h: Int, s: Int, v: Int)? {
        guard UserDefaults.standard.object(forKey: hueKey) != nil,
              UserDefaults.standard.object(forKey: saturationKey) != nil,
              UserDefaults.standard.object(forKey: valueKey) != nil else {
            return nil
        }
        let h = UserDefaults.standard.integer(forKey: hueKey)
        let s = UserDefaults.standard.integer(forKey: saturationKey)
        let v = UserDefaults.standard.integer(forKey: valueKey)
        return (h: h, s: s, v: v)
    }
}
