//
//  main.swift
//  TextParser
//
//  Created by Dominik de Jesus Moreira on 29.03.26.
//

import Foundation
import NaturalLanguage

@main
struct App {
    static func main() {
        print()
        let text = CommandLine.arguments.dropFirst().joined(separator: " ")
        let sentiment = sentiment(for: text)
        print("Sentiment analysis: \(sentiment)")
    }

    static func sentiment(for string: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = string

        let (sentiment, _) = tagger.tag(
            at: string.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )

        return Double(sentiment?.rawValue ?? "0") ?? 0

    }
}
