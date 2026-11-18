//
//  BreastTimerView.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  모유 직접 수유 좌/우 타이머 (AddEventView 의 모유 → "직접 수유" 모드).
//  - 큰 왼쪽/오른쪽 버튼: 탭하면 시작, 다시 탭하면 일시정지, 반대쪽 탭하면 전환
//  - 시간은 "시작 시각" 기준으로 계산 → 화면이 꺼지거나 다른 앱에 다녀와도 정확 (앱이 종료되면 사라짐)
//  - ±1분 버튼: 수유가 끝난 뒤 기억으로 입력할 때
//  - 지난번에 끝난 쪽의 반대쪽을 "이번엔 여기부터"로 강조
//

import SwiftUI

/// 타이머 상태 (순수 값 타입 — 단위 테스트 대상)
struct BreastTimer: Equatable {
    var leftSec = 0
    var rightSec = 0
    /// 지금 재고 있는 쪽
    var active: BreastSide?
    var activeSince: Date?
    /// 처음 시작한 시각 → 기록 시각으로 쓴다
    var firstStartedAt: Date?
    /// 마지막으로 먹인 쪽 → 다음 수유 안내에 쓴다
    var lastSide: BreastSide?

    var isRunning: Bool { active != nil }

    func seconds(_ side: BreastSide, now: Date = Date()) -> Int {
        let base = side == .left ? leftSec : rightSec
        guard active == side, let since = activeSince else { return base }
        return base + max(Int(now.timeIntervalSince(since)), 0)
    }

    func total(now: Date = Date()) -> Int { seconds(.left, now: now) + seconds(.right, now: now) }

    /// 진행 중인 쪽의 시간을 확정하고 멈춘다
    mutating func stop(now: Date = Date()) {
        guard let side = active else { return }
        set(side, seconds(side, now: now))
        active = nil
        activeSince = nil
    }

    /// 시작 / 일시정지 / 반대쪽으로 전환
    mutating func toggle(_ side: BreastSide, now: Date = Date()) {
        let wasActive = active == side
        stop(now: now)
        guard !wasActive else { return }
        active = side
        activeSince = now
        lastSide = side
        if firstStartedAt == nil { firstStartedAt = now }
    }

    /// 수동 보정 (분 단위). 0 미만으로 내려가지 않는다.
    mutating func adjust(_ side: BreastSide, minutes: Int, now: Date = Date()) {
        if active == side { stop(now: now) }
        set(side, max(seconds(side, now: now) + minutes * 60, 0))
        if minutes > 0 { lastSide = side }
    }

    private mutating func set(_ side: BreastSide, _ value: Int) {
        if side == .left { leftSec = value } else { rightSec = value }
    }

    static func clock(_ sec: Int) -> String { String(format: "%d:%02d", sec / 60, sec % 60) }
}

struct BreastTimerSection: View {
    @Binding var timer: BreastTimer
    /// 이번에 먼저 먹일 쪽 (지난번 마지막 쪽의 반대)
    let suggested: BreastSide?

    var body: some View {
        // 진행 중일 때만 1초마다 다시 그린다
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    sideButton(.left, now: context.date)
                    sideButton(.right, now: context.date)
                }
                HStack {
                    Text("총 \(BreastTimer.clock(timer.total(now: context.date)))")
                        .font(.subheadline.monospacedDigit())
                    Spacer()
                    if let suggested, timer.firstStartedAt == nil, timer.total() == 0 {
                        Text("지난번 반대쪽 → 이번엔 \(suggested.label)부터")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func sideButton(_ side: BreastSide, now: Date) -> some View {
        let running = timer.active == side
        let highlight = running || (timer.total() == 0 && suggested == side)
        return VStack(spacing: 8) {
            Button {
                timer.toggle(side)
            } label: {
                VStack(spacing: 4) {
                    Text(side.label).font(.headline)
                    Text(BreastTimer.clock(timer.seconds(side, now: now)))
                        .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    Label(running ? "일시정지" : "시작", systemImage: running ? "pause.fill" : "play.fill")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
                .foregroundStyle(running ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(running ? Color.accentColor : Color(.secondarySystemFill)))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(highlight && !running ? Color.accentColor : .clear, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(side.label) \(running ? "일시정지" : "시작")")

            HStack(spacing: 6) {
                Button("−1분") { timer.adjust(side, minutes: -1) }
                Button("+1분") { timer.adjust(side, minutes: 1) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
