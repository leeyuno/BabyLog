//
//  WHOGrowth.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  WHO 아동 성장 표준 — 연령별 체중(weight-for-age), 0~24개월, LMS 방식.
//  데이터 출처: WHO Child Growth Standards (CDC 배포본 WHO-Boys/Girls-Weight-for-age-Percentiles.csv)
//    값 = M × (1 + L·S·z)^(1/L),   z = ((값/M)^L − 1) / (L·S)
//  개월 사이 값은 L·M·S 를 선형 보간한다.
//  ⚠️ 표 숫자를 손으로 고치지 말 것. 진단이 아닌 참고용 — UI 에 반드시 안내 문구를 함께 표시.
//  (Android lib/domain/who_growth.dart 와 같은 표)
//

import Foundation

enum WHOGrowth {
    struct LMS: Equatable {
        let l: Double, m: Double, s: Double
        init(_ l: Double, _ m: Double, _ s: Double) { self.l = l; self.m = m; self.s = s }
    }

    static let maxMonths = 24.0

    /// 표시할 백분위 곡선과 해당 z 값
    static let curves: [(percentile: Int, z: Double)] = [
        (3, -1.880794), (15, -1.036433), (50, 0), (85, 1.036433), (97, 1.880794)
    ]

    // 0~24개월 (index = 개월)
    static let boys: [LMS] = [
        LMS(0.3487, 3.3464, 0.14602), LMS(0.2297, 4.4709, 0.13395), LMS(0.197, 5.5675, 0.12385),
        LMS(0.1738, 6.3762, 0.11727), LMS(0.1553, 7.0023, 0.11316), LMS(0.1395, 7.5105, 0.1108),
        LMS(0.1257, 7.934, 0.10958), LMS(0.1134, 8.297, 0.10902), LMS(0.1021, 8.6151, 0.10882),
        LMS(0.0917, 8.9014, 0.10881), LMS(0.082, 9.1649, 0.10891), LMS(0.073, 9.4122, 0.10906),
        LMS(0.0644, 9.6479, 0.10925), LMS(0.0563, 9.8749, 0.10949), LMS(0.0487, 10.0953, 0.10976),
        LMS(0.0413, 10.3108, 0.11007), LMS(0.0343, 10.5228, 0.11041), LMS(0.0275, 10.7319, 0.11079),
        LMS(0.0211, 10.9385, 0.11119), LMS(0.0148, 11.143, 0.11164), LMS(0.0087, 11.3462, 0.11211),
        LMS(0.0029, 11.5486, 0.11261), LMS(-0.0028, 11.7504, 0.11314), LMS(-0.0083, 11.9514, 0.11369),
        LMS(-0.0137, 12.1515, 0.11426)
    ]

    static let girls: [LMS] = [
        LMS(0.3809, 3.2322, 0.14171), LMS(0.1714, 4.1873, 0.13724), LMS(0.0962, 5.1282, 0.13),
        LMS(0.0402, 5.8458, 0.12619), LMS(-0.005, 6.4237, 0.12402), LMS(-0.043, 6.8985, 0.12274),
        LMS(-0.0756, 7.297, 0.12204), LMS(-0.1039, 7.6422, 0.12178), LMS(-0.1288, 7.9487, 0.12181),
        LMS(-0.1507, 8.2254, 0.12199), LMS(-0.17, 8.48, 0.12223), LMS(-0.1872, 8.7192, 0.12247),
        LMS(-0.2024, 8.9481, 0.12268), LMS(-0.2158, 9.1699, 0.12283), LMS(-0.2278, 9.387, 0.12294),
        LMS(-0.2384, 9.6008, 0.12299), LMS(-0.2478, 9.8124, 0.12303), LMS(-0.2562, 10.0226, 0.12306),
        LMS(-0.2637, 10.2315, 0.12309), LMS(-0.2703, 10.4393, 0.12315), LMS(-0.2762, 10.6464, 0.12323),
        LMS(-0.2815, 10.8534, 0.12335), LMS(-0.2862, 11.0608, 0.1235), LMS(-0.2903, 11.2688, 0.12369),
        LMS(-0.2941, 11.4775, 0.1239)
    ]

    /// 0~24개월 범위의 보간된 LMS. 성별 미상·범위 밖이면 nil.
    static func lms(sex: BabySex, months: Double) -> LMS? {
        let table: [LMS]
        switch sex {
        case .boy: table = boys
        case .girl: table = girls
        case .unknown: return nil
        }
        guard months >= 0, months <= maxMonths else { return nil }
        let i = Int(months.rounded(.down))
        if i >= table.count - 1 { return table[table.count - 1] }
        let t = months - Double(i)
        let a = table[i], b = table[i + 1]
        return LMS(a.l + (b.l - a.l) * t, a.m + (b.m - a.m) * t, a.s + (b.s - a.s) * t)
    }

    /// z 점수에 해당하는 체중(kg)
    static func weight(z: Double, lms p: LMS) -> Double {
        abs(p.l) < 1e-9 ? p.m * exp(p.s * z) : p.m * pow(1 + p.l * p.s * z, 1 / p.l)
    }

    static func zScore(weight: Double, lms p: LMS) -> Double {
        abs(p.l) < 1e-9 ? log(weight / p.m) / p.s : (pow(weight / p.m, p.l) - 1) / (p.l * p.s)
    }

    /// 백분위(0~100). 같은 성별·개월수 아기 100명 중 이 체중보다 가벼운 아기 수.
    static func percentile(weight: Double, sex: BabySex, months: Double) -> Double? {
        guard let p = lms(sex: sex, months: months) else { return nil }
        let z = zScore(weight: weight, lms: p)
        return 50 * (1 + erf(z / 2.0.squareRoot()))
    }
}
