//
//  BabyLogWidget.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2025/09/21.
//

import WidgetKit
import SwiftUI
import Intents
import CoreData

struct BabyLogElapsedEntry: TimelineEntry {
    let date: Date
    let elasped: String
}

private let groupID = "group.com.leeyuno.BabyLog"

struct BabyLogElapsedProvider: TimelineProvider {
    func placeholder(in context: Context) -> BabyLogElapsedEntry {
        BabyLogElapsedEntry(date: Date(), elasped: "--:--")
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyLogElapsedEntry) -> Void) {
        completion(makeEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyLogElapsedEntry>) -> Void) {
        let entry = makeEntry()
        
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func makeEntry() -> BabyLogElapsedEntry {
        let container = sharedContainer()
        let context = container.viewContext
        
        let request: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.predicate = NSPredicate(format: "kindRaw == %d", CareKind.feed.rawValue)
        request.fetchLimit = 1

        if let lastFeed = try? context.fetch(request).first {
            let components = Calendar.current.dateComponents([.hour, .minute], from: lastFeed.createdAt, to: Date())
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0

            return BabyLogElapsedEntry(date: Date(), elasped: "\(hour)시간 \(minute)분")
        } else {
            return BabyLogElapsedEntry(date: Date(), elasped: "기록 없음")
        }
    }
    
    private func sharedContainer() -> NSPersistentContainer {
        let c = NSPersistentContainer(name: "BabyLog") // ← .xcdatamodeld 이름과 동일
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)!
            .appendingPathComponent("BabyLog.sqlite")
        let desc = NSPersistentStoreDescription(url: storeURL)
        c.persistentStoreDescriptions = [desc]

        var loaded = false
        c.loadPersistentStores { _, error in
            if let error = error { print("CoreData load error:", error) }
            loaded = true
        }
        if !loaded { print("CoreData model not loaded") }
        return c
    }
}

struct BabyLogWidgetEntryView : View {
    var entry: BabyLogElapsedProvider.Entry

    var body: some View {
        ZStack {
            Color(.systemBackground)
            VStack {
                Text("마지막 수유 이후")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(entry.elasped)
                    .font(.title3)
                    .bold()
            }
            .padding()
        }
    }
}

struct BabyLogElapsedWidget: Widget {
    let kind: String = "BabyLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyLogElapsedProvider()) { entry in
            BabyLogWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("수유 경과 시간")
        .description("마지막 수유로부터 얼마나 지났는지 보여줍니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

//struct BabyLogWidget_Previews: PreviewProvider {
//    static var previews: some View {
//        BabyLogWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent()))
//            .previewContext(WidgetPreviewContext(family: .systemSmall))
//    }
//}
