import SwiftUI
import Combine
import ActivityKit

enum WorkState {
    case idle
    case running
    case paused
}

// MARK: - 1. VERİ MODELİ
struct WorkSession: Codable, Identifiable {
    var id = UUID(); var date: Date; var duration: Int
}

class SessionManager: ObservableObject {
    @Published var sessions: [WorkSession] = []
    @Published var dailyGoals: [String: Int] = [:]
    @Published var dailyNotes: [String: String] = [:]
    
    init() { loadData() }
    
    func totalDuration(for date: Date) -> Int {
        let cal = Calendar.current
        return sessions.filter { cal.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.duration }
    }
    func goal(for date: Date) -> Int { dailyGoals[dateKey(for: date)] ?? (3 * 3600) }
    func setGoal(hours: Int, for date: Date) { dailyGoals[dateKey(for: date)] = hours * 3600; saveData() }
    func note(for date: Date) -> String { dailyNotes[dateKey(for: date)] ?? "" }
    func setNote(_ text: String, for date: Date) { dailyNotes[dateKey(for: date)] = text; saveData() }
    func saveSession(duration: Int, date: Date = Date()) {
        sessions.append(WorkSession(date: date, duration: duration)); saveData()
    }
    
    private func dateKey(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(encoded, forKey: "allSessions") }
        UserDefaults.standard.set(dailyGoals, forKey: "dailyGoals")
        UserDefaults.standard.set(dailyNotes, forKey: "dailyNotes")
    }
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "allSessions"), let decoded = try? JSONDecoder().decode([WorkSession].self, from: data) { sessions = decoded }
        if let savedGoals = UserDefaults.standard.dictionary(forKey: "dailyGoals") as? [String: Int] { dailyGoals = savedGoals }
        if let savedNotes = UserDefaults.standard.dictionary(forKey: "dailyNotes") as? [String: String] { dailyNotes = savedNotes }
    }
}

// MARK: - 2. ANA EKRAN (SOYUT ARKAPLANLI ZEN TASARIMI)
struct ContentView: View {
    @StateObject private var sessionManager = SessionManager()
    @State private var currentState: WorkState = .idle
    @State private var elapsedTimeInSeconds = 0
    @State private var selectedDate: Date = Date()
    @State private var showDayDetail = false
    @State private var hoveredDate: Date? = nil
    
    @State private var currentActivity: Activity<TimerAttributes>? = nil
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var currentTotalForToday: Int { sessionManager.totalDuration(for: Date()) + elapsedTimeInSeconds }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // SOYUT YIN-YANG ARKAPLAN
                GeometryReader { geometry in
                    Image("yinyang_bg") // Assets klasöründeki görsel
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                        // Görselin çok bağırmaması ve yazıları yutmaması için koyu bir katman
                        .overlay(Color.black.opacity(currentState == .running ? 0.6 : 0.8))
                        // Sayaç çalışırken görsel yavaşça aydınlanır/belirginleşir
                        .animation(.easeInOut(duration: 2.0), value: currentState)
                }
                
                VStack(spacing: 40) { // Boşlukları artırarak ferahlattık
                    Spacer()
                    
                    // DEV ZAMANLAYICI
                    VStack(spacing: 10) {
                        Text(formatTime(currentTotalForToday))
                            .font(.system(size: 75, weight: .ultraLight, design: .rounded))
                            .foregroundColor(currentState == .paused ? .gray : .white)
                            .onReceive(timer) { _ in
                                syncWithLiveActivity()
                                if currentState == .running { elapsedTimeInSeconds += 1 }
                            }
                        
                        let todayGoal = sessionManager.goal(for: Date())
                        let deficit = todayGoal - currentTotalForToday
                        Text(deficit > 0 ? "Kalan: \(formatTime(deficit))" : "Denge Sağlandı")
                            .font(.subheadline).tracking(2)
                            .foregroundColor(deficit > 0 ? .gray : .white)
                    }
                    
                    // 7 GÜNLÜK DÖNGÜ (Yuvarlaklar)
                    VStack(alignment: .center, spacing: 15) {
                        HStack(spacing: 12) {
                            ForEach(0..<7, id: \.self) { index in
                                let date = Calendar.current.date(byAdding: .day, value: -(6 - index), to: Date()) ?? Date()
                                let record = sessionManager.totalDuration(for: date)
                                let note = sessionManager.note(for: date)
                                
                                VStack(spacing: 8) {
                                    Text(dateLabel(for: date)).font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                                    
                                    Circle()
                                        .fill(colorForRecord(date: date, seconds: record, target: sessionManager.goal(for: date)))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            ZStack(alignment: .topTrailing) {
                                                if record > 0 && record < sessionManager.goal(for: date) {
                                                    Circle().stroke(Color.white, lineWidth: 1)
                                                }
                                                if !note.isEmpty {
                                                    Circle().fill(record >= sessionManager.goal(for: date) ? Color.black : Color.white).frame(width: 4, height: 4).position(x: 20, y: 30)
                                                }
                                            }
                                        )
                                        .onTapGesture { selectedDate = date; showDayDetail = true }
                                        .onLongPressGesture(minimumDuration: 0.5) { if !note.isEmpty { hoveredDate = date } }
                                        .popover(isPresented: Binding(get: { hoveredDate == date }, set: { if !$0 { hoveredDate = nil } }), attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                                            Text(note).font(.callout).padding().frame(maxWidth: 200).presentationCompactAdaptation(.popover)
                                        }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // MİNİMALİST BUTONLAR
                    VStack(spacing: 15) {
                        if currentState == .idle {
                            ActionButton(title: "BAŞLAT", isPrimary: true) { currentState = .running; startLiveActivity() }
                        } else if currentState == .running {
                            HStack(spacing: 15) {
                                ActionButton(title: "DURAKLAT", isPrimary: false) { currentState = .paused; updateLiveActivity(isPaused: true) }
                                ActionButton(title: "SONLANDIR", isPrimary: true) { finishSession() }
                            }
                        } else if currentState == .paused {
                            HStack(spacing: 15) {
                                ActionButton(title: "DEVAM", isPrimary: true) { currentState = .running; updateLiveActivity(isPaused: false) }
                                ActionButton(title: "SONLANDIR", isPrimary: false) { finishSession() }
                            }
                        }
                    }
                    .padding(.horizontal, 30).padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HistoryCalendarView(sessionManager: sessionManager)) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2).fontWeight(.light).foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showDayDetail) {
                DayDetailView(date: selectedDate, sessionManager: sessionManager, isPresented: $showDayDetail, onManualUpdate: {
                    if currentState != .idle { updateLiveActivity(isPaused: currentState == .paused) }
                }).presentationDetents([.fraction(0.85), .large])
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func dateLabel(for date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "EE"; return f.string(from: date).uppercased()
    }
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func colorForRecord(date: Date, seconds: Int, target: Int) -> Color {
        let cal = Calendar.current
        if cal.startOfDay(for: date) > cal.startOfDay(for: Date()) { return Color.white.opacity(0.05) }
        if seconds >= target { return Color.white }
        return Color.white.opacity(0.15)
    }
    
    func finishSession() {
        currentState = .idle
        if elapsedTimeInSeconds > 0 { sessionManager.saveSession(duration: elapsedTimeInSeconds) }
        endLiveActivity()
        elapsedTimeInSeconds = 0
    }
    
    func syncWithLiveActivity() {
        if Activity<TimerAttributes>.activities.isEmpty && currentState != .idle { finishSession(); return }
        if let activity = Activity<TimerAttributes>.activities.first {
            let state = activity.content.state
            if state.isPaused && currentState == .running { currentState = .paused; elapsedTimeInSeconds = state.totalWorkedSeconds - sessionManager.totalDuration(for: Date()) }
            else if !state.isPaused && currentState == .paused { currentState = .running }
        }
    }
    
    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TimerAttributes.ContentState(isPaused: false, totalWorkedSeconds: sessionManager.totalDuration(for: Date()), lastStartDate: Date(), goalSeconds: sessionManager.goal(for: Date()))
        do { currentActivity = try Activity.request(attributes: TimerAttributes(goalName: "Denge"), content: .init(state: state, staleDate: nil)) } catch { }
    }
    func updateLiveActivity(isPaused: Bool) {
        let total = sessionManager.totalDuration(for: Date()) + elapsedTimeInSeconds
        let state = TimerAttributes.ContentState(isPaused: isPaused, totalWorkedSeconds: total, lastStartDate: isPaused ? nil : Date(), goalSeconds: sessionManager.goal(for: Date()))
        Task { await currentActivity?.update(ActivityContent(state: state, staleDate: nil)) }
    }
    func endLiveActivity() {
        let total = sessionManager.totalDuration(for: Date()) + elapsedTimeInSeconds
        let state = TimerAttributes.ContentState(isPaused: true, totalWorkedSeconds: total, lastStartDate: nil, goalSeconds: sessionManager.goal(for: Date()))
        Task { await currentActivity?.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default) }
    }
}

// MARK: - 3. GÜN DETAYI
struct DayDetailView: View {
    let date: Date
    @ObservedObject var sessionManager: SessionManager
    @Binding var isPresented: Bool
    var onManualUpdate: (() -> Void)?
    
    @State private var selectedGoalHours: Int = 3
    @State private var manualHours: Int = 0
    @State private var manualMinutes: Int = 0
    @State private var dayNote: String = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 25) {
                        Text(formattedDate).font(.title2).fontWeight(.light).padding(.top, 30)
                        
                        let total = sessionManager.totalDuration(for: date)
                        let goal = sessionManager.goal(for: date)
                        let deficit = goal - total
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("ÇALIŞILAN").font(.caption).foregroundColor(.gray)
                                Text(formatTime(total)).font(.title3).fontWeight(.medium)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                Text("KALAN").font(.caption).foregroundColor(.gray)
                                Text(deficit > 0 ? formatTime(deficit) : "Tamamlandı").font(.title3).fontWeight(.medium).foregroundColor(deficit > 0 ? .white : .gray)
                            }
                        }.padding(.horizontal, 30)
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 30)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("NOTLAR").font(.caption).foregroundColor(.gray).tracking(1)
                            TextEditor(text: $dayNote)
                                .font(.body).frame(height: 100).padding(8)
                                .scrollContentBackground(.hidden).background(Color.black.opacity(0.3)).cornerRadius(10)
                                .onChange(of: dayNote) { oldValue, newValue in sessionManager.setNote(newValue, for: date) }
                        }.padding(.horizontal, 30)
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 30)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("HEDEF BELİRLE").font(.caption).foregroundColor(.gray).tracking(1)
                            Stepper(value: $selectedGoalHours, in: 1...24) { Text("\(selectedGoalHours) Saat").font(.body) }
                            .onChange(of: selectedGoalHours) { oldValue, newValue in
                                sessionManager.setGoal(hours: newValue, for: date)
                                if Calendar.current.isDateInToday(date) { onManualUpdate?() }
                            }
                        }.padding(.horizontal, 30)
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 30)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("MANUEL EKLE").font(.caption).foregroundColor(.gray).tracking(1)
                            HStack(spacing: 20) {
                                VStack { Text("Saat").font(.caption2).foregroundColor(.gray); Stepper("\(manualHours)", value: $manualHours, in: 0...23) }
                                VStack { Text("Dakika").font(.caption2).foregroundColor(.gray); Stepper("\(manualMinutes)", value: $manualMinutes, in: 0...59, step: 5) }
                            }
                            Button(action: {
                                let totalSeconds = (manualHours * 3600) + (manualMinutes * 60)
                                if totalSeconds > 0 {
                                    sessionManager.saveSession(duration: totalSeconds, date: date); manualHours = 0; manualMinutes = 0
                                    if Calendar.current.isDateInToday(date) { onManualUpdate?() }
                                }
                            }) {
                                Text("EKLE").font(.subheadline).fontWeight(.bold).tracking(1).foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.white).clipShape(Capsule())
                            }.disabled(manualHours == 0 && manualMinutes == 0)
                        }.padding(.horizontal, 30)
                        
                        Spacer(minLength: 30)
                    }
                }
                
                Button(action: { isPresented = false }) { Text("KAPAT").font(.subheadline).fontWeight(.bold).tracking(1).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.white.opacity(0.1)).clipShape(Capsule()) }
                .padding(.horizontal, 30).padding(.bottom, 20).padding(.top, 10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { selectedGoalHours = sessionManager.goal(for: date) / 3600; dayNote = sessionManager.note(for: date) }
    }
    
    var formattedDate: String { let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateStyle = .long; return f.string(from: date) }
    func formatTime(_ seconds: Int) -> String { let h = seconds / 3600; let m = (seconds % 3600) / 60; return "\(h)s \(m)dk" }
}

// MARK: - 4. MAKRO TAKVİM ARŞİVİ
struct HistoryCalendarView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var displayMonth = Date()
    @State private var selectedDate = Date()
    @State private var showDayDetail = false
    @State private var hoveredDate: Date? = nil
    
    let daysOfWeek = ["P", "S", "Ç", "P", "C", "C", "P"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Takvim ekranı da simsiyah kalıyor
            
            VStack(spacing: 20) {
                HStack {
                    Button(action: { displayMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth }) { Image(systemName: "chevron.left").foregroundColor(.white) }
                    Spacer(); Text(monthYearString(from: displayMonth)).font(.headline).fontWeight(.light).tracking(2).foregroundColor(.white); Spacer()
                    Button(action: { displayMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth }) { Image(systemName: "chevron.right").foregroundColor(.white) }
                }
                .padding(.horizontal, 30).padding(.top, 20)
                
                HStack { ForEach(daysOfWeek, id: \.self) { day in Text(day).font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity) } }.padding(.horizontal, 20)
                
                LazyVGrid(columns: columns, spacing: 15) {
                    let days = generateDaysInMonth(for: displayMonth)
                    ForEach(0..<days.count, id: \.self) { index in
                        if let date = days[index] {
                            let total = sessionManager.totalDuration(for: date)
                            let goal = sessionManager.goal(for: date)
                            let note = sessionManager.note(for: date)
                            
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 16, weight: .light, design: .rounded)).foregroundColor(total >= goal ? .black : .white).frame(width: 40, height: 40)
                                .background(calendarColorForDate(date: date, total: total, goal: goal)).clipShape(Circle())
                                .overlay(
                                    ZStack {
                                        if !note.isEmpty { Circle().fill(total >= goal ? Color.white : Color.gray).frame(width: 4, height: 4).offset(x: 0, y: 12) }
                                    }
                                )
                                .onTapGesture { selectedDate = date; showDayDetail = true }
                                .onLongPressGesture(minimumDuration: 0.5) { if !note.isEmpty { hoveredDate = date } }
                                .popover(isPresented: Binding(get: { hoveredDate == date }, set: { if !$0 { hoveredDate = nil } }), attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                                    Text(note).font(.callout).padding().frame(maxWidth: 200).presentationCompactAdaptation(.popover)
                                }
                        } else { Text("").frame(width: 40, height: 40) }
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .navigationTitle("ARŞİV").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDayDetail) {
            DayDetailView(date: selectedDate, sessionManager: sessionManager, isPresented: $showDayDetail).presentationDetents([.fraction(0.85), .large])
        }
    }
    
    func monthYearString(from date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "MMMM yyyy"; return f.string(from: date).uppercased() }
    func calendarColorForDate(date: Date, total: Int, goal: Int) -> Color {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date()); let target = cal.startOfDay(for: date)
        if target > today { return Color.clear } else if total >= goal { return Color.white } else { return Color.white.opacity(0.1) }
    }
    func generateDaysInMonth(for date: Date) -> [Date?] {
        var cal = Calendar.current; cal.firstWeekday = 2
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)), let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: startOfMonth)
        let offset = (firstWeekday - 2 + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for dayOffset in 0..<range.count { if let dayDate = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth) { days.append(dayDate) } }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// Kapsül Şeklinde Özel Buton Yapısı
struct ActionButton: View {
    var title: String; var isPrimary: Bool; var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline).fontWeight(.bold).tracking(2)
                .foregroundColor(isPrimary ? .black : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(isPrimary ? Color.white : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}
