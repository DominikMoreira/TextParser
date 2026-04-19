//
//  main.swift
//  TextParser
//
//  Created by Dominik de Jesus Moreira on 29.03.26.
//

import ArgumentParser
import Foundation
import NaturalLanguage

@main
struct App: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "analyze",
            abstract:
                "Analyzes input text using a range of natural language approaches."
        )
    }

    @Argument(help: "The text you want to analyze")
    var input: [String]
    
    @Flag(name: .shortAndLong, help: "Run everything in one go.")
    var everything = false

    @Flag(name: .shortAndLong, help: "Show detected language.")
    var detectLanguage = false

    @Flag(
        name: .shortAndLong,
        help: "Prints how positive or negative the input is."
    )
    var sentimentAnalysis = false

    @Flag(
        name: .shortAndLong,
        help: "Shows the stem form of each word in the input."
    )
    var lemmatize = false

    @Flag(
        name: .shortAndLong,
        help: "Prints alternative words for each word in the input."
    )
    var alternatives = false

    @Flag(
        name: .shortAndLong,
        help: "Prints names of people, places, and organizations in the input."
    )
    var names = false

    @Flag(help: "Detect person names.")
    var person = false

    @Flag(help: "Detect place names.")
    var place = false

    @Flag(help: "Detect organization names.")
    var organization = false

    @Option(help: "The maximum number of alternatives to suggest.")
    var maximumAlternatives = 10
    
    @Option(help: "Distance level of alternatives which should be shown.")
    var minimumAlternativeDistance: Double = 0.4

    mutating func run() {
        if everything
        {
            detectLanguage = true
            sentimentAnalysis = true
            lemmatize = true
            alternatives = true
            names = true
        }

        if person || place || organization {
            names = true
        }

        print()
        let text = input.joined(separator: " ")

        let language =
            NLLanguageRecognizer.dominantLanguage(for: text)
            ?? .undetermined
        if detectLanguage {
            print()
            print("Detected Language: \(language.rawValue)")
        }

        if sentimentAnalysis {
            let sentiment = sentiment(for: text)
            print("Sentiment analysis: \(sentiment)")
        }

        lazy var lemma = lemmatize(string: text)
        if lemmatize {
            print()
            print("Found the following lemma:")
            print("\t", lemma.formatted(.list(type: .and)))
        }

        if alternatives {
            print()
            print("Found the following alternatives:")

            for word in lemma {
                let embeddings = embeddings(for: word, for: language)
                print("\t\n\(word): ", embeddings.formatted(.list(type: .and)))
            }
        }

        if names {
            let entities = entities(
                for: text,
                includePersons: person,
                includePlaces: place,
                includeOrganizations: organization
            )
            print()
            print("Found the following entities:")
            for entity in entities {
                print("\t", entity)
            }
        }
    }

    func sentiment(for string: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = string

        let (sentiment, _) = tagger.tag(
            at: string.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )

        return Double(sentiment?.rawValue ?? "0") ?? 0
    }

    func embeddings(for word: String, for language: NLLanguage) -> [String] {
        var results = [String]()

        if let embedding = NLEmbedding.wordEmbedding(for: language) {
            let similarWords = embedding.neighbors(
                for: word,
                maximumCount: maximumAlternatives
            )

            for word in similarWords {
                if word.1 >= minimumAlternativeDistance {
                    results.append("\(word.0) has a distance of word \(word.1)")
                }
            }
        }

        return results
    }

    func lemmatize(string: String) -> [String] {
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

    func entities(
        for string: String,
        includePersons: Bool,
        includePlaces: Bool,
        includeOrganizations: Bool
    ) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = string

        let hasExplicitSelection =
            includePersons || includePlaces || includeOrganizations

        let allowedTags: Set<NLTag>
        if hasExplicitSelection {
            var tags = Set<NLTag>()

            if includePersons {
                tags.insert(.personalName)
            }
            if includePlaces {
                tags.insert(.placeName)
            }
            if includeOrganizations {
                tags.insert(.organizationName)
            }

            allowedTags = tags
        } else {
            allowedTags = [.personalName, .placeName, .organizationName]
        }

        var results = [String]()

        tagger.enumerateTags(
            in: string.startIndex..<string.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.joinNames, .omitWhitespace, .omitPunctuation]
        ) { tag, range in
            guard let tag = tag, allowedTags.contains(tag) else {
                return true
            }

            let match = String(string[range])

            switch tag {
            case .organizationName:
                results.append("Organization: \(match)")
            case .personalName:
                results.append("Person: \(match)")
            case .placeName:
                results.append("Place: \(match)")
            default:
                break
            }

            return true
        }

        return results
    }
}
