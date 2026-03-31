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

        let lemma = lemmatize(string: text)
        print()
        print("Found the following alternatives:")
        for word in lemma {
            let embeddings = embeddings(for: word)
            print("\t\(word): ", embeddings.formatted(.list(type: .and)))
        }
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

    static func embeddings(for word: String) -> [String] {
        var results = [String]()

        if let embedding = NLEmbedding.wordEmbedding(for: .english) {
            let similarWords = embedding.neighbors(for: word, maximumCount: 10)

            for word in similarWords {
                results.append("\(word.0) has a distance of word \(word.1)")
            }
        }

        return results
    }

    static func lemmatize(string: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = string

        var results = [String]()

        tagger.enumerateTags(
            in: string.startIndex..<string.endIndex,
            unit: .word,
            scheme: .lemma
        ) {
            tag,
            range in
            let stemForm =
                tag?.rawValue
                ?? String(string[range]).trimmingCharacters(in: .whitespaces)

            if stemForm.isEmpty == false {
                results.append(stemForm)
            }

            return true
        }

        return results
    }
}
