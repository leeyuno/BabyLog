//
//  BabyLogOneTapWidget.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2026/11/18.
//
//  "원탭 기록" 위젯 (iOS 17+ 인터랙티브 위젯, 위젯 타깃 전용).
//  [소변] [대변] [분유 N ml] [잠들었어요 / 깼어요] — 탭하면 앱을 열지 않고 바로 저장한다.
//  - 저장: LogCareIntent → OneTapLog.perform → SharedPersistence.write (위젯 프로세스)
//  - 앱은 영속 히스토리로 이 변경을 병합한다 (PersistentHistoryMerger)
//  - 잘못 눌렀으면 앱 타임라인에서 탭해 수정/삭제
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct LogCareIntent: AppIntent {
    static var title: LocalizedStringResource = "먹싸자 빠른 기록"
    static var description = IntentDescription("앱을 열지 않고 기록합니다.")

    @Parameter(title: "동작") var action: String

    init() {}
    init(_ action: OneTapAction) { self.action = action.rawValue }

    func perform() async throws -> some IntentResult {
        guard let act = OneTapAction(rawValue: action) else { return .result() }
        let text: String? = SharedPersistence.write { ctx in
            guard let baby = SharedPersistence.firstBaby(in: ctx) else { return nil }
            return OneTapLog.perform(act, baby: baby, in: ctx)
        } ?? nil
        if let text {
            UserDefaults(suiteName: BabyLogGroup.appGroupId)?.set(text, forKey: OneTapLog.lastResultKey)
        }
        WidgetCenter.shared.reloadAllTimelines()   // 수유 경과·오늘 통계 위젯도 갱신
        return .result()
    }
}

struct OneTapEntry: TimelineEntry {
    let date: Date
    let hasBaby: Bool
    let status: OneTapLog.Status
    let lastResult: String?
}

struct OneTapProvider: TimelineProvider {
    func placeholder(in context: Context) -> OneTapEntry {
        OneTapEntry(date: .now, hasBaby: true, status: .init(formulaML: 120, sleepingSince: nil), lastResult: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OneTapEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OneTapEntry>) -> Void) {
        // 내용은 탭(인텐트)·앱 저장 때 갱신되므로 주기 갱신은 길게
        completion(Timeline(entries: [makeEntry()], policy: .after(.now.addingTimeInterval(3600))))
    }

    private func makeEntry() -> OneTapEntry {
        let status: OneTapLog.Status? = SharedPersistence.read { ctx -> OneTapLog.Status? in
            guard let baby = SharedPersistence.firstBaby(in: ctx) else { return nil }
            return OneTapLog.status(for: baby, in: ctx)
        } ?? nil
        let last = UserDefaults(suiteName: BabyLogGroup.appGroupId)?.string(forKey: OneTapLog.lastResultKey)
        return OneTapEntry(date: .now, hasBaby: status != nil,
                           status: status ?? .init(formulaML: OneTapLog.defaultFormulaML, sleepingSince: nil),
                           lastResult: last)
    }
}

@available(iOS 17.0, *)
struct OneTapWidgetView: View {
    let entry: OneTapEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let last = entry.lastResult {
                Label(last, systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green).lineLimit(1)
            } else {
                Text("탭 한 번으로 바로 기록돼요").font(.caption).foregroundStyle(.secondary)
            }
            if entry.hasBaby {
                HStack(spacing: 6) {
                    button(.pee, title: "소변", icon: "drop.fill", tint: .orange)
                    button(.poop, title: "대변", icon: "circle.fill", tint: .brown)
                    button(.formula, title: "분유 \(entry.status.formulaML)", icon: "waterbottle.fill", tint: .blue)
                    if let since = entry.status.sleepingSince {
                        sleepButton(title: "깼어요", since: since)
                    } else {
                        button(.sleep, title: "잠들었어요", icon: "moon.zzz.fill", tint: .indigo)
                    }
                }
            } else {
                Text("앱에서 아기를 먼저 등록하세요").font(.subheadline)
            }
        }
        .widgetBackground()
    }

    private func button(_ action: OneTapAction, title: String, icon: String, tint: Color) -> some View {
        Button(intent: LogCareIntent(action)) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .tint(tint)
        .buttonStyle(.bordered)
    }

    private func sleepButton(title: String, since: Date) -> some View {
        Button(intent: LogCareIntent(.sleep)) {
            VStack(spacing: 2) {
                Image(systemName: "sun.max.fill").font(.title3)
                Text(title).font(.caption2.weight(.semibold))
                Text(since, style: .timer).font(.system(size: 9).monospacedDigit()).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .tint(.indigo)
        .buttonStyle(.borderedProminent)
    }
}

@available(iOS 17.0, *)
struct BabyLogOneTapWidget: Widget {
    var body: some WidgetConfiguration {
        // ⚠️ kind 문자열을 바꾸면 사용자가 추가해 둔 위젯이 사라진다
        StaticConfiguration(kind: "BabyLogOneTapWidget", provider: OneTapProvider()) { entry in
            OneTapWidgetView(entry: entry)
        }
        .configurationDisplayName("원탭 기록")
        .description("앱을 열지 않고 기저귀·분유·수면을 바로 기록합니다.")
        .supportedFamilies([.systemMedium])
    }
}
