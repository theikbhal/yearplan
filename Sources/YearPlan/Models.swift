import SwiftUI

struct Person: Identifiable, Codable, Hashable { var id = UUID(); var name: String; var emoji: String }

enum AccountKind: String, Codable, CaseIterable, Identifiable {
    case hand = "Cash at hand", home = "Cash at home", purse = "Purse", locker = "Locker", bank = "Bank"
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .hand: return "💵"
        case .home: return "🏠"
        case .purse: return "👛"
        case .locker: return "🔐"
        case .bank: return "🏦"
        }
    }
}

struct Account: Identifiable, Codable { var id = UUID(); var name: String; var kind: AccountKind; var balance: Double = 0 }
struct Cat: Identifiable, Codable, Hashable { var id = UUID(); var name: String; var emoji: String; var isIncome = false; var yearlyPlan: Double = 0 }

struct Entry: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var title: String
    var amount: Double
    var isIncome = false
    var category: String
    var tags: [String] = []          // one expense can fall under many things
    var personIDs: [UUID] = []       // one expense can be for many people
    var accountID: UUID?
    var note = ""
}

struct DB: Codable {
    var people: [Person]
    var accounts: [Account]
    var cats: [Cat]
    var entries: [Entry] = []

    static var starter: DB {
        DB(people: [Person(name: "Ikbhal", emoji: "🧔"), Person(name: "Wife", emoji: "👩"),
                    Person(name: "Towheed", emoji: "👦"), Person(name: "Tauqeer", emoji: "🧒"),
                    Person(name: "Faaiza", emoji: "👧")],
           accounts: AccountKind.allCases.map { Account(name: $0.rawValue, kind: $0) },
           cats: [
            Cat(name: "Rental income", emoji: "🏘️", isIncome: true), Cat(name: "Other income", emoji: "💰", isIncome: true),
            Cat(name: "Rent", emoji: "🏠"), Cat(name: "Rice", emoji: "🍚"), Cat(name: "Oil", emoji: "🛢️"),
            Cat(name: "Dal", emoji: "🫘"), Cat(name: "Biscuit", emoji: "🍪"), Cat(name: "Mutton", emoji: "🍖"),
            Cat(name: "Chicken", emoji: "🍗"), Cat(name: "Vegetables", emoji: "🥦"), Cat(name: "Fruits", emoji: "🍎"),
            Cat(name: "Kids school", emoji: "🎒"), Cat(name: "College fee", emoji: "🎓"),
            Cat(name: "Bike petrol", emoji: "⛽"), Cat(name: "Bike maintenance", emoji: "🔧"),
            Cat(name: "Clothes", emoji: "👕"), Cat(name: "Eat outside", emoji: "🍔"), Cat(name: "Adhoc", emoji: "🎲")
           ])
    }
}

enum Period: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", month = "Month", quarter = "Quarter", year = "Year"
    var id: String { rawValue }
    func range(_ d: Date) -> (Date, Date) {
        let c = Calendar.current
        switch self {
        case .day: let s = c.startOfDay(for: d); return (s, c.date(byAdding: .day, value: 1, to: s)!)
        case .week: let i = c.dateInterval(of: .weekOfYear, for: d)!; return (i.start, i.end)
        case .month: let i = c.dateInterval(of: .month, for: d)!; return (i.start, i.end)
        case .quarter:
            let q = (c.component(.month, from: d) - 1) / 3
            let s = c.date(from: DateComponents(year: c.component(.year, from: d), month: q * 3 + 1, day: 1))!
            return (s, c.date(byAdding: .month, value: 3, to: s)!)
        case .year: let i = c.dateInterval(of: .year, for: d)!; return (i.start, i.end)
        }
    }
    var fraction: Double {
        switch self {
        case .day: return 1.0 / 365
        case .week: return 7.0 / 365
        case .month: return 1.0 / 12
        case .quarter: return 0.25
        case .year: return 1
        }
    }
}

func money(_ v: Double) -> String { "₹" + String(format: "%.0f", v) }

final class Store: ObservableObject {
    @Published var db: DB { didSet { save() } }
    static let url: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("YearPlan")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("data.json")
    }()

    init() {
        if let d = try? Data(contentsOf: Self.url), let x = try? JSONDecoder().decode(DB.self, from: d) { db = x } else { db = DB.starter }
    }
    func save() { if let d = try? JSONEncoder().encode(db) { try? d.write(to: Self.url) } }

    func add(_ e: Entry) {
        db.entries.insert(e, at: 0)
        if let id = e.accountID, let i = db.accounts.firstIndex(where: { $0.id == id }) {
            db.accounts[i].balance += e.isIncome ? e.amount : -e.amount
        }
    }
    func remove(_ e: Entry) {
        if let id = e.accountID, let i = db.accounts.firstIndex(where: { $0.id == id }) {
            db.accounts[i].balance += e.isIncome ? -e.amount : e.amount
        }
        db.entries.removeAll { $0.id == e.id }
    }

    func list(_ p: Period, _ d: Date) -> [Entry] { let r = p.range(d); return db.entries.filter { $0.date >= r.0 && $0.date < r.1 } }
    func actual(_ cat: String, _ p: Period, _ d: Date) -> Double { list(p, d).filter { $0.category == cat }.reduce(0) { $0 + $1.amount } }
    func total(income: Bool, _ p: Period, _ d: Date) -> Double { list(p, d).filter { $0.isIncome == income }.reduce(0) { $0 + $1.amount } }
    var cash: Double { db.accounts.reduce(0) { $0 + $1.balance } }

    var streak: Int {
        let c = Calendar.current
        let days = Set(db.entries.map { c.startOfDay(for: $0.date) })
        var d = c.startOfDay(for: Date())
        if !days.contains(d) { d = c.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while days.contains(d) { n += 1; d = c.date(byAdding: .day, value: -1, to: d)! }
        return n
    }
    var coins: Int { db.entries.count * 5 + streak * 10 }
    var level: Int { coins / 100 + 1 }
    var monthPlan: Double { db.cats.filter { !$0.isIncome }.reduce(0) { $0 + $1.yearlyPlan } * Period.month.fraction }
    /// Energy = how much of this month's plan is still left
    var energy: Double {
        guard monthPlan > 0 else { return 1 }
        return max(0, 1 - total(income: false, .month, Date()) / monthPlan)
    }
}

let reminders: [(String, String)] = [
    ("Actions are judged by intentions. Make your niyyat: I plan to be safe and ease my family.", "Bukhari & Muslim"),
    ("Plan, tie your camel, then trust Allah (tawakkul).", "Tirmidhi"),
    ("Whoever relies on Allah, He is enough for him.", "Quran 65:3"),
    ("Allah does not burden a soul beyond its capacity. No anxiety, just the next small step.", "Quran 2:286"),
    ("Spend neither wastefully nor stingily, but between the two.", "Quran 25:67"),
    ("Fear Allah wherever you are.", "Tirmidhi"),
    ("A person follows the way of his close friend, so choose friends well.", "Abu Dawud & Tirmidhi"),
    ("Whoever humbles himself for Allah, Allah raises him (tawazo).", "Muslim"),
    ("Rizq is from Allah. Your job: halal effort and a written plan.", "Reminder")
]
