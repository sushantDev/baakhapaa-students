//
//  ReadingStreakWidget.swift
//  ReadingStreakWidget
//
//  Created by sushant sapkota on 13/03/2026.
//

import WidgetKit
import SwiftUI

struct ReadingStreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let totalChapters: Int
    let totalBooks: Int
    let lastBook: String
    let streakEmoji: String
}

struct ReadingStreakProvider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.baakhapaa.com")

    func placeholder(in context: Context) -> ReadingStreakEntry {
        ReadingStreakEntry(date: Date(), streakDays: 0, totalChapters: 0, totalBooks: 0, lastBook: "", streakEmoji: "📚")
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStreakEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingStreakEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> ReadingStreakEntry {
        let streakDays = userDefaults?.integer(forKey: "streak_days") ?? 0
        let totalChapters = userDefaults?.integer(forKey: "total_chapters") ?? 0
        let totalBooks = userDefaults?.integer(forKey: "total_books") ?? 0
        let lastBook = userDefaults?.string(forKey: "last_book") ?? ""
        let streakEmoji = userDefaults?.string(forKey: "streak_emoji") ?? "📚"
        return ReadingStreakEntry(
            date: Date(),
            streakDays: streakDays,
            totalChapters: totalChapters,
            totalBooks: totalBooks,
            lastBook: lastBook,
            streakEmoji: streakEmoji
        )
    }
}

// Flame icon with red→orange→amber gradient on iOS 15+, plain amber on older versions
private struct FlameIcon: View {
    let isActive: Bool
    var body: some View {
        let symbol = isActive ? "flame.fill" : "flame"
        if #available(iOS 15.0, *) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isActive
                    ? AnyShapeStyle(LinearGradient(
                        colors: [
                            Color(red: 0.898, green: 0.224, blue: 0.208), // #E53935 red base
                            Color(red: 1.0,   green: 0.596, blue: 0.0),   // #FF9800 orange mid
                            Color(red: 1.0,   green: 0.761, blue: 0.031)  // #FFC208 amber tip
                        ],
                        startPoint: .bottom,
                        endPoint: .top))
                    : AnyShapeStyle(Color.gray))
        } else {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(isActive ? Color(red: 1.0, green: 0.761, blue: 0.031) : .gray)
        }
    }
}

struct ReadingStreakWidgetView: View {
    let entry: ReadingStreakEntry

    // App brand colors
    private let bgColor = Color(red: 0.06, green: 0.06, blue: 0.06)       // #101010
    private let cardColor = Color(red: 0.10, green: 0.10, blue: 0.10)     // #1A1A1A
    private let amber = Color(red: 1.0, green: 0.76, blue: 0.03)          // #FFC208
    private let amberDim = Color(red: 1.0, green: 0.76, blue: 0.03).opacity(0.15)

    var body: some View {
        VStack(spacing: 0) {
            // Streak flame + count (Duolingo-style hero)
            HStack(spacing: 6) {
                FlameIcon(isActive: entry.streakDays > 0)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.streakDays)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(entry.streakDays == 1 ? "day streak" : "day streak")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)

            // Stats row
            HStack(spacing: 8) {
                Label("\(entry.totalChapters)", systemImage: "doc.text.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Label("\(entry.totalBooks)", systemImage: "books.vertical.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)

            Spacer()

            // CTA / Last book
            if entry.streakDays == 0 {
                Text("Start your streak!")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(amber)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !entry.lastBook.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 10))
                        .foregroundColor(amber)
                    Text(entry.lastBook)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(amber)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(bgColor)
    }
}

struct ReadingStreakWidget: Widget {
    let kind: String = "ReadingStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingStreakProvider()) { entry in
            ReadingStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Streak")
        .description("Track your learning streak")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    ReadingStreakWidget()
} timeline: {
    ReadingStreakEntry(date: .now, streakDays: 7, totalChapters: 30, totalBooks: 3, lastBook: "Atomic Habits", streakEmoji: "🔥")
    ReadingStreakEntry(date: .now, streakDays: 0, totalChapters: 0, totalBooks: 0, lastBook: "", streakEmoji: "📚")
}
