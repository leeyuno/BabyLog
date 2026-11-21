//
//  TimelineView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  최근 24시간 기록 목록 (createdAt 내림차순).
//  - + 버튼: 새 기록 시트
//  - 상단: 다음 수유 예상 카드 (FeedSchedule)
//  - 행 탭 / 스와이프 "편집": AddEventView(editing:) — 종류·수유량·시간·메모 모두 수정
//  - 스와이프 "삭제" (풀 스와이프 삭제는 실수 방지를 위해 비활성)
//  ⚠️ 24시간 기준 시각은 init 시점에 고정된다. 앱을 오래 켜두면 범위가 갱신되지 않을 수 있음.
//

import SwiftUI
import CoreData

struct TimelineView: View {
    let baby: Baby
    @Environment(\.managedObjectContext) private var context
    @State private var showAddSheet = false

    @FetchRequest private var events: FetchedResults<CareEvent>

    @State private var editingEvent: CareEvent?

    init(baby: Baby) {
        self.baby = baby
        let since = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date().addingTimeInterval(-86400)
        let predicate = NSPredicate(format: "baby == %@ AND createdAt >= %@", baby, since as NSDate)
        _events = FetchRequest<CareEvent>(
            entity: CareEvent.entity(),
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    List {
                        // 다음 수유 예상 (수유 3회 이상일 때). events 가 바뀌면 다시 계산된다.
                        if let prediction = FeedSchedule.prediction(for: baby, in: context) {
                            NextFeedCard(prediction: prediction)
                        }
                        if events.isEmpty {
                            EmptyStateView(
                                title: "기록 없음",
                                systemImage: "calendar.badge.exclamationmark",
                                message: "오른쪽 위 + 버튼으로 첫 기록을 추가하세요."
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(events) { ev in
                                // 행 전체 탭 → 편집 (모든 필드 수정 가능)
                                Button {
                                    editingEvent = ev
                                } label: {
                                    EventRowView(event: ev)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                // .swipeActions 를 쓰면 .onDelete 기본 삭제가 숨겨지므로 삭제도 직접 둔다.
                                // 졸린 상태의 실수 방지를 위해 풀 스와이프 삭제는 막는다.
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        delete(ev)
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                    Button {
                                        editingEvent = ev
                                    } label: {
                                        Label("편집", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        if AdsConfig.showsAds {
                            BannerView(adUnitID: AdsConfig.bannerUnitID)
                                .frame(height: 60)            // Adaptive 배너 높이 ≈ 50~60
                                .listRowInsets(EdgeInsets())  // 좌우 여백 제거
                                .listRowSeparator(.hidden)    // 구분선 제거
                        }
                    }
                }
                .navigationTitle("\(baby.name) 타임라인")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        BabyAvatarView(baby: baby, size: 32)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
                .sheet(isPresented: $showAddSheet) {
                    AddEventView(baby: baby)
                        .environment(\.managedObjectContext, context)
                }
                .sheet(item: $editingEvent) { ev in
                    // 시트 안에서 삭제한 경우 dismiss 도중 재평가될 수 있어 삭제된 객체는 그리지 않는다
                    if !ev.isDeleted, ev.managedObjectContext != nil {
                        AddEventView(editing: ev)
                            .environment(\.managedObjectContext, context)
                    }
                }
            }
        }

    private func delete(_ event: CareEvent) {
        context.delete(event)
        do {
            try context.saveAndRefreshWidgets()
        } catch {
            print("Delete error:", error.localizedDescription)
        }
    }
}

/// "다음 수유 약 14:30" — 1분마다 남은 시간/지난 시간을 갱신
private struct NextFeedCard: View {
    let prediction: FeedSchedule.Prediction

    var body: some View {
        SwiftUI.TimelineView(.everyMinute) { context in
            let remaining = prediction.next.timeIntervalSince(context.date)
            HStack(spacing: 12) {
                Image(systemName: "clock.badge")
                    .font(.title2)
                    .foregroundStyle(remaining < 0 ? Color.orange : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("다음 수유 약 \(prediction.next.formatted(date: .omitted, time: .shortened))")
                        .font(.headline)
                    Text(statusText(remaining) + " · 평균 \(FeedSchedule.intervalText(prediction.interval)) 간격")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private func statusText(_ remaining: TimeInterval) -> String {
        let text = FeedSchedule.intervalText(abs(remaining))
        return remaining >= 0 ? "\(text) 남음" : "예상 시각에서 \(text) 지남"
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PreviewPersistence.controller.container.viewContext

        let request: NSFetchRequest<Baby> = Baby.fetchRequest()
        let baby = (try? context.fetch(request).first) ?? {
            let b = Baby(context: context)
            b.id = UUID()
            b.name = "Preview Baby"
            b.birthday = Date()
            return b
        }()

        TimelineView(baby: baby)
            .environment(\.managedObjectContext, context)
    }
}
