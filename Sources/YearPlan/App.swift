import SwiftUI

@main
struct YearPlanApp: App {
    @StateObject var store = Store()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store).frame(minWidth: 900, minHeight: 620) }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case today = "Today", plan = "Plan vs Actual", accounts = "Money", people = "Family", rewards = "Rewards", reports = "Reports", help = "Help"
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .today: return "✅"
        case .plan: return "🎯"
        case .accounts: return "🏦"
        case .people: return "👨‍👩‍👧‍👦"
        case .rewards: return "🏆"
        case .reports: return "📊"
        case .help: return "❓"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var s: Store
    @AppStorage("easy") var easy = false
    @AppStorage("seenIntro") var seenIntro = false
    @State var tab: Tab? = .today

    var body: some View {
        NavigationSplitView {
            VStack {
                List(Tab.allCases, selection: $tab) { t in
                    Text("\(t.emoji)  \(t.rawValue)").font(easy ? .title3 : .body).tag(t)
                }
                Toggle("Easy mode (big buttons)", isOn: $easy).padding()
            }
        } detail: {
            switch tab ?? .today {
            case .today: TodayView()
            case .plan: PlanView()
            case .accounts: AccountsView()
            case .people: PeopleView()
            case .rewards: RewardsView()
            case .reports: ReportsView()
            case .help: HelpView()
            }
        }
        .sheet(isPresented: Binding(get: { !seenIntro }, set: { _ in })) {
            VStack(spacing: 14) {
                Text("🌙 Bismillah").font(.largeTitle)
                Text("Welcome to YearPlan").font(.title2)
                Text("Make your niyyat: planning is to bring ease and safety to your family, not anxiety.\n\n1. Tap a picture on Today to add money in or out.\n2. Set a yearly plan in Plan vs Actual.\n3. Keep your streak and earn coins.\n\nYou plan, Allah provides. 🤲").multilineTextAlignment(.center)
                Button("Start") { seenIntro = true }.keyboardShortcut(.defaultAction)
            }.padding(30).frame(width: 460)
        }
    }
}

// MARK: Today
struct TodayView: View {
    @EnvironmentObject var s: Store
    @AppStorage("easy") var easy = false
    @State var sheetCat: Cat?
    @State var pulse = false
    @State var r = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let rem = reminders[r % reminders.count]
                VStack(alignment: .leading, spacing: 4) {
                    Text("🕌 \(rem.0)").font(easy ? .title2 : .headline)
                    Text(rem.1).font(.caption).foregroundStyle(.secondary)
                    Button("Next reminder") { withAnimation { r += 1 } }.buttonStyle(.link)
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 12) {
                    chip("🪙", "\(s.coins) coins")
                    chip("🔥", "\(s.streak)-day streak")
                    chip("⭐", "Level \(s.level)")
                    VStack(alignment: .leading) {
                        Text("⚡ Energy (month plan left)").font(.caption)
                        ProgressView(value: s.energy).tint(s.energy > 0.3 ? .green : .red)
                    }.frame(width: 190)
                }.scaleEffect(pulse ? 1.015 : 1)
                 .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true } }

                Text("Tap to add").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: easy ? 170 : 110))], spacing: 12) {
                    ForEach(s.db.cats) { c in
                        Button { sheetCat = c } label: {
                            VStack {
                                Text(c.emoji).font(.system(size: easy ? 56 : 34))
                                Text(c.name).font(easy ? .title3 : .caption)
                            }.frame(maxWidth: .infinity).padding(easy ? 20 : 10)
                             .background(c.isIncome ? Color.green.opacity(0.15) : Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).accessibilityLabel("Add \(c.isIncome ? "income" : "expense") \(c.name)")
                    }
                }

                Text("Recent").font(.headline)
                ForEach(s.db.entries.prefix(15)) { e in
                    HStack {
                        Text(e.isIncome ? "⬆️" : "⬇️")
                        VStack(alignment: .leading) {
                            Text(e.title).bold()
                            Text(([e.category] + e.tags).joined(separator: " · ") + (e.note.isEmpty ? "" : " — \(e.note)")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(money(e.amount)).foregroundStyle(e.isIncome ? .green : .primary)
                        Text(e.date, format: .dateTime.day().month()).font(.caption)
                        Button("🗑️") { withAnimation { s.remove(e) } }.buttonStyle(.plain)
                    }
                }
            }.padding()
        }
        .sheet(item: $sheetCat) { c in AddSheet(catName: c.name) }
    }
    func chip(_ e: String, _ t: String) -> some View {
        Text("\(e) \(t)").padding(8).background(Color.orange.opacity(0.15), in: Capsule())
    }
}

struct AddSheet: View {
    @EnvironmentObject var s: Store
    @Environment(\.dismiss) var dismiss
    @State var catName: String
    @State var title = ""
    @State var amount = ""
    @State var accountID: UUID?
    @State var people = Set<UUID>()
    @State var tags = ""
    @State var note = ""
    @State var date = Date()

    var body: some View {
        Form {
            Picker("Category", selection: $catName) { ForEach(s.db.cats) { Text("\($0.emoji) \($0.name)").tag($0.name) } }
            TextField("What (optional)", text: $title)
            TextField("Amount ₹", text: $amount).font(.title2)
            DatePicker("Date", selection: $date, displayedComponents: .date)
            Picker("Account", selection: $accountID) {
                Text("None").tag(UUID?.none)
                ForEach(s.db.accounts) { Text("\($0.kind.emoji) \($0.name)").tag(Optional($0.id)) }
            }
            Text("For whom?").font(.headline)
            HStack {
                ForEach(s.db.people) { p in
                    Toggle("\(p.emoji) \(p.name)", isOn: Binding(
                        get: { people.contains(p.id) },
                        set: { if $0 { people.insert(p.id) } else { people.remove(p.id) } })).toggleStyle(.button)
                }
            }
            TextField("Tags, comma separated (e.g. eid, school, guests)", text: $tags)
            TextField("Note", text: $note)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save 🪙") { save() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 520)
    }
    func save() {
        guard let v = Double(amount.replacingOccurrences(of: ",", with: "")), v > 0 else { return }
        let c = s.db.cats.first { $0.name == catName }
        let t = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        withAnimation(.spring()) {
            s.add(Entry(date: date, title: title.isEmpty ? catName : title, amount: v, isIncome: c?.isIncome ?? false,
                        category: catName, tags: t, personIDs: Array(people), accountID: accountID, note: note))
        }
        dismiss()
    }
}

// MARK: Plan vs Actual
struct PlanView: View {
    @EnvironmentObject var s: Store
    @State var period = Period.month
    @State var editing = false
    var body: some View {
        let now = Date()
        List {
            Picker("", selection: $period) { ForEach(Period.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            let inc = s.total(income: true, period, now), exp = s.total(income: false, period, now)
            HStack {
                stat("⬆️ Income", inc); stat("⬇️ Spent", exp); stat("💧 Cashflow", inc - exp)
            }
            Toggle("Edit yearly plan", isOn: $editing)
            if editing {
                ForEach($s.db.cats) { $c in
                    HStack { Text("\(c.emoji) \(c.name)"); Spacer(); TextField("yearly ₹", value: $c.yearlyPlan, format: .number).frame(width: 120) }
                }
            } else {
                ForEach(s.db.cats.filter { $0.yearlyPlan > 0 || s.actual($0.name, period, now) > 0 }) { c in
                    let plan = c.yearlyPlan * period.fraction, act = s.actual(c.name, period, now)
                    let bad = c.isIncome ? act < plan : act > plan
                    VStack(alignment: .leading) {
                        HStack { Text("\(c.emoji) \(c.name)"); Spacer(); Text("\(money(act)) / \(money(plan))").foregroundStyle(bad ? .red : .green) }
                        ProgressView(value: plan > 0 ? min(1, act / plan) : 0).tint(bad ? .red : .green)
                    }
                }
            }
        }
    }
    func stat(_ t: String, _ v: Double) -> some View {
        VStack { Text(t).font(.caption); Text(money(v)).font(.title2.bold()) }.frame(maxWidth: .infinity)
    }
}

// MARK: Money
struct AccountsView: View {
    @EnvironmentObject var s: Store
    var body: some View {
        List {
            Text("Total: \(money(s.cash))").font(.largeTitle.bold())
            ForEach($s.db.accounts) { $a in
                HStack {
                    Text(a.kind.emoji)
                    TextField("Name", text: $a.name)
                    Spacer()
                    TextField("₹", value: $a.balance, format: .number).frame(width: 140).multilineTextAlignment(.trailing)
                }
            }
            Menu("➕ Add account") {
                ForEach(AccountKind.allCases) { k in Button("\(k.emoji) \(k.rawValue)") { s.db.accounts.append(Account(name: k.rawValue, kind: k)) } }
            }
        }
    }
}

struct PeopleView: View {
    @EnvironmentObject var s: Store
    var body: some View {
        List {
            ForEach($s.db.people) { $p in
                let spent = s.db.entries.filter { !$0.isIncome && $0.personIDs.contains(p.id) }
                    .reduce(0.0) { $0 + $1.amount / Double($1.personIDs.count) }
                HStack {
                    TextField("😀", text: $p.emoji).frame(width: 50)
                    TextField("Name", text: $p.name)
                    Spacer()
                    Text("Spent: \(money(spent))")
                    Button("🗑️") { s.db.people.removeAll { $0.id == p.id } }.buttonStyle(.plain)
                }
            }
            Button("➕ Add person") { s.db.people.append(Person(name: "New", emoji: "🙂")) }
        }
    }
}

// MARK: Rewards
struct RewardsView: View {
    @EnvironmentObject var s: Store
    var body: some View {
        let mp = s.monthPlan, ms = s.total(income: false, .month, Date())
        let badges: [(String, String, Bool)] = [
            ("🌱", "First step", !s.db.entries.isEmpty),
            ("🔥", "7-day streak", s.streak >= 7),
            ("📒", "50 entries", s.db.entries.count >= 50),
            ("🏦", "3 places of money tracked", s.db.accounts.filter { $0.balance > 0 }.count >= 3),
            ("👨‍👩‍👧", "Family added", s.db.people.count >= 2),
            ("🛡️", "Month within plan", mp > 0 && ms <= mp && !s.db.entries.isEmpty)
        ]
        let enemies = s.db.cats.filter { !$0.isIncome && $0.yearlyPlan > 0 && s.actual($0.name, .month, Date()) > $0.yearlyPlan * Period.month.fraction }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🪙 \(s.coins) coins · ⭐ Level \(s.level) · 🔥 \(s.streak) days").font(.title.bold())
                Text("Badges").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
                    ForEach(badges, id: \.1) { b in
                        VStack { Text(b.0).font(.system(size: 44)); Text(b.1).font(.caption) }
                            .frame(maxWidth: .infinity).padding().opacity(b.2 ? 1 : 0.25)
                            .background(Color.yellow.opacity(b.2 ? 0.2 : 0.05), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                Text("Enemies this month 😈").font(.headline)
                if enemies.isEmpty { Text("No enemies. Alhamdulillah! 🎉") }
                ForEach(enemies) { c in
                    Text("😈 \(c.name) is over plan: \(money(s.actual(c.name, .month, Date()))) vs \(money(c.yearlyPlan * Period.month.fraction))").foregroundStyle(.red)
                }
                Text("Benefits of the yearly plan").font(.headline)
                Text("• Calm mind: you know what is coming.\n• Less waste, more sadaqah and savings.\n• Family always knows where money is.\n• Avoid debt and bad spending habits.\n• Stay with good people; avoid places that tempt you to overspend.")
            }.padding()
        }
    }
}

// MARK: Reports
struct ReportsView: View {
    @EnvironmentObject var s: Store
    var body: some View {
        let now = Date()
        let inc = s.total(income: true, .year, now), exp = s.total(income: false, .year, now)
        let yearEntries = s.list(.year, now).filter { !$0.isIncome }
        var tagTotals: [String: Double] = [:]
        let _ = yearEntries.forEach { e in e.tags.forEach { tagTotals[$0, default: 0] += e.amount } }
        let planExp = s.db.cats.filter { !$0.isIncome }.reduce(0) { $0 + $1.yearlyPlan }
        let planInc = s.db.cats.filter { $0.isIncome }.reduce(0) { $0 + $1.yearlyPlan }
        let yearlyNeed = max(planExp, exp), yearlyIn = max(planInc, inc)
        List {
            Section("This year") {
                Text("Income \(money(inc)) · Spent \(money(exp)) · Net \(money(inc - exp))")
                Text("Plan: income \(money(planInc)) · expense \(money(planExp))")
            }
            Section("By tag") { ForEach(tagTotals.sorted { $0.value > $1.value }, id: \.key) { Text("\($0.key): \(money($0.value))") } }
            Section("Future outlook (no inflation; cash now + income − expenses)") {
                ForEach([2, 3, 5, 7, 14], id: \.self) { n in
                    let left = s.cash + Double(n) * (yearlyIn - yearlyNeed)
                    Text("\(n) years: \(money(left))").foregroundStyle(left >= 0 ? .green : .red)
                }
            }
            Section("Export") {
                Button("Save CSV + backup to Desktop") { export() }
            }
        }
    }
    func export() {
        let desk = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        var csv = "date,title,category,amount,income,tags,note\n"
        for e in s.db.entries {
            csv += "\(e.date.formatted(.iso8601.year().month().day())),\"\(e.title)\",\(e.category),\(e.amount),\(e.isIncome),\"\(e.tags.joined(separator: ";"))\",\"\(e.note)\"\n"
        }
        try? csv.write(to: desk.appendingPathComponent("YearPlan-expenses.csv"), atomically: true, encoding: .utf8)
        try? FileManager.default.copyItem(at: Store.url, to: desk.appendingPathComponent("YearPlan-backup-\(Int(Date().timeIntervalSince1970)).json"))
    }
}

// MARK: Help
struct HelpView: View {
    var body: some View {
        ScrollView {
            Text("""
            ❓ Help

            ✅ Today: tap a picture, type the amount, Save. Pick people and tags if you want (one expense can belong to many people and many tags).
            🎯 Plan vs Actual: switch Day / Week / Month / Quarter / Year. Turn on "Edit yearly plan" to set the amount for each item.
            🏦 Money: cash at hand, home, purse, locker, bank. Balances change when you pick an account while adding.
            👨‍👩‍👧‍👦 Family: add or rename people and see spending for each.
            🏆 Rewards: coins, streaks, badges and enemies (items over plan).
            📊 Reports: yearly totals, tags, 2/3/5/7/14-year outlook, and export.

            🕋 Handover (if something happens to me): keep the exported backup safe. Tell your wife or elder son where the file and bank details are. Open the backup JSON or CSV; accounts and balances are inside.

            🤲 Tawakkul: plan, then trust Allah. Tawazo: stay humble. Taqwa: fear Allah. Keep good company and avoid bad habits.

            Easy mode = bigger buttons. Coming later: voice, blind, lazy and ADHD modes, Android, Chrome extension, website.
            """).padding().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
