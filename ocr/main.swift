//
//  main.swift
//  OCR
//
//  Created by Marcus Schappi on 17/5/21, 11:36 am
//

import Foundation
import CoreImage
import Cocoa
import Vision
import ScreenCapture
import ArgumentParserKit

let defaultRecognitionLanguages = ["en-US"]
let defaultOllamaHost = "http://127.0.0.1:11434"
let defaultOllamaPrompt = """
Extract all readable text from this image.
Return only the transcribed text.
Preserve line breaks and obvious spacing when possible.
Do not summarize, translate, add markdown, or describe the image.
If no readable text is present, return an empty string.
"""

enum OCRBackend: String {
    case auto
    case vision
    case ollama
}

struct RectValues {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

struct OllamaConfiguration {
    let host: String
    let model: String
    let prompt: String
}

struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let images: [String]
    let stream: Bool
    let options: OllamaOptions
}

struct OllamaOptions: Encodable {
    let temperature: Int
}

struct OllamaGenerateResponse: Decodable {
    let response: String?
    let error: String?
}

struct OllamaTagsResponse: Decodable {
    let models: [OllamaTagModel]
}

struct OllamaTagModel: Decodable {
    let name: String?
    let model: String?
}

enum AppError: LocalizedError {
    case invalidRect(String)
    case unsupportedBackend(String)
    case unsupportedLanguageSelection
    case inputFileNotFound(String)
    case failedToLoadImage(String)
    case failedToCreateCGImage(String)
    case screenCaptureFailed
    case missingOllamaModel
    case invalidOllamaHost(String)
    case requestTimedOut
    case invalidOllamaResponse
    case ollamaRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRect(let value):
            return "--rect requires x,y,width,height. Received: \(value)"
        case .unsupportedBackend(let value):
            return "Unsupported backend '\(value)'. Use 'auto', 'vision', or 'ollama'."
        case .unsupportedLanguageSelection:
            return "--language with the Vision backend requires macOS 11.0 or later."
        case .inputFileNotFound(let path):
            return "Input file does not exist: \(path)"
        case .failedToLoadImage(let path):
            return "Unable to load image: \(path)"
        case .failedToCreateCGImage(let path):
            return "Unable to convert image into a CGImage: \(path)"
        case .screenCaptureFailed:
            return "Screen capture did not produce an image."
        case .missingOllamaModel:
            return "No Ollama model was configured or auto-detected. Set --ollama-model or OLLAMA_MODEL."
        case .invalidOllamaHost(let value):
            return "Invalid Ollama host URL: \(value)"
        case .requestTimedOut:
            return "The request to Ollama timed out."
        case .invalidOllamaResponse:
            return "Ollama returned an unexpected response."
        case .ollamaRequestFailed(let message):
            return message
        }
    }
}

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent)
}

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

func emitRecognizedText(_ text: String) {
    print(text)
    copyToClipboard(text)
}

func parseBackend(_ value: String?) throws -> OCRBackend {
    let backendName = (value ?? OCRBackend.auto.rawValue).lowercased()
    guard let backend = OCRBackend(rawValue: backendName) else {
        throw AppError.unsupportedBackend(backendName)
    }
    return backend
}

func parseRect(_ value: String?) throws -> RectValues? {
    guard let value = value, !value.isEmpty else {
        return nil
    }

    let parts = value.split(separator: ",").compactMap { Int($0) }
    guard parts.count == 4 else {
        throw AppError.invalidRect(value)
    }

    return RectValues(x: parts[0], y: parts[1], w: parts[2], h: parts[3])
}

func recognitionLanguagesForVision(languageHint: String?) throws -> [String] {
    guard let languageHint = languageHint, !languageHint.isEmpty else {
        return defaultRecognitionLanguages
    }

    guard #available(macOS 11.0, *) else {
        throw AppError.unsupportedLanguageSelection
    }

    return [languageHint] + defaultRecognitionLanguages
}

func recognizeTextWithVision(fileURL: URL, recognitionLanguages: [String]) throws -> String {
    guard let ciImage = CIImage(contentsOf: fileURL) else {
        throw AppError.failedToLoadImage(fileURL.path)
    }

    guard let cgImage = convertCIImageToCGImage(inputImage: ciImage) else {
        throw AppError.failedToCreateCGImage(fileURL.path)
    }

    var recognizedText = ""
    var recognitionError: Error?

    let request = VNRecognizeTextRequest { request, error in
        if let error = error {
            recognitionError = error
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            recognizedText = ""
            return
        }

        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        recognizedText = recognizedStrings.joined(separator: "\n")
    }

    request.recognitionLanguages = recognitionLanguages
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
    try requestHandler.perform([request])

    if let recognitionError = recognitionError {
        throw recognitionError
    }

    return recognizedText
}

func makeOllamaAPIURL(host: String, endpoint: String) throws -> URL {
    let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard var components = URLComponents(string: trimmedHost),
          components.scheme != nil,
          components.host != nil else {
        throw AppError.invalidOllamaHost(host)
    }

    let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if normalizedPath.isEmpty {
        components.path = "/api/\(endpoint)"
    } else {
        components.path = "/\(normalizedPath)/api/\(endpoint)"
    }

    guard let url = components.url else {
        throw AppError.invalidOllamaHost(host)
    }

    return url
}

func ollamaModelSelectionScore(_ modelName: String) -> Int {
    let normalized = modelName.lowercased()
    var score = 0

    if normalized.contains("ocr") { score += 100 }
    if normalized.contains("vision") { score += 80 }
    if normalized.contains("vl") { score += 70 }
    if normalized.contains("llava") { score += 60 }
    if normalized.contains("glm") { score += 20 }
    if normalized.hasSuffix(":latest") { score += 5 }

    return score
}

func detectPreferredOllamaModel(host: String) throws -> String? {
    var request = URLRequest(url: try makeOllamaAPIURL(host: host, endpoint: "tags"))
    request.httpMethod = "GET"
    request.timeoutInterval = 10

    let (data, response) = try performDataRequest(request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AppError.invalidOllamaResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw AppError.ollamaRequestFailed(
            decodeOllamaErrorMessage(statusCode: httpResponse.statusCode, data: data)
        )
    }

    let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
    let modelNames = decoded.models.compactMap { $0.name ?? $0.model }
    guard !modelNames.isEmpty else {
        return nil
    }

    return modelNames.sorted { lhs, rhs in
        let lhsScore = ollamaModelSelectionScore(lhs)
        let rhsScore = ollamaModelSelectionScore(rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }
        if lhs.count != rhs.count {
            return lhs.count < rhs.count
        }
        return lhs < rhs
    }.first
}

func makeOllamaPrompt(basePrompt: String, languageHint: String?) -> String {
    guard let languageHint = languageHint, !languageHint.isEmpty else {
        return basePrompt
    }

    return """
    \(basePrompt)

    Prefer OCR output in this language/locale when the image is ambiguous: \(languageHint)
    """
}

func performDataRequest(_ request: URLRequest) throws -> (Data, URLResponse) {
    let semaphore = DispatchSemaphore(value: 0)

    var responseData = Data()
    var response: URLResponse?
    var responseError: Error?

    URLSession.shared.dataTask(with: request) { data, urlResponse, error in
        responseData = data ?? Data()
        response = urlResponse
        responseError = error
        semaphore.signal()
    }.resume()

    let timeout = DispatchTime.now() + request.timeoutInterval + 5
    if semaphore.wait(timeout: timeout) == .timedOut {
        throw AppError.requestTimedOut
    }

    if let responseError = responseError {
        throw responseError
    }

    guard let response = response else {
        throw AppError.invalidOllamaResponse
    }

    return (responseData, response)
}

func decodeOllamaErrorMessage(statusCode: Int, data: Data) -> String {
    if let decoded = try? JSONDecoder().decode(OllamaGenerateResponse.self, from: data),
       let error = decoded.error,
       !error.isEmpty {
        return "Ollama request failed (\(statusCode)): \(error)"
    }

    if let body = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
       !body.isEmpty {
        return "Ollama request failed (\(statusCode)): \(body)"
    }

    return "Ollama request failed with HTTP \(statusCode)."
}

func recognizeTextWithOllama(fileURL: URL, configuration: OllamaConfiguration, languageHint: String?) throws -> String {
    let endpointURL = try makeOllamaAPIURL(host: configuration.host, endpoint: "generate")
    let imageData = try Data(contentsOf: fileURL)
    let requestBody = OllamaGenerateRequest(
        model: configuration.model,
        prompt: makeOllamaPrompt(basePrompt: configuration.prompt, languageHint: languageHint),
        images: [imageData.base64EncodedString()],
        stream: false,
        options: OllamaOptions(temperature: 0)
    )

    var request = URLRequest(url: endpointURL)
    request.httpMethod = "POST"
    request.timeoutInterval = 120
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (data, response) = try performDataRequest(request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AppError.invalidOllamaResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw AppError.ollamaRequestFailed(
            decodeOllamaErrorMessage(statusCode: httpResponse.statusCode, data: data)
        )
    }

    let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

    if let error = decoded.error, !error.isEmpty {
        throw AppError.ollamaRequestFailed("Ollama returned an error: \(error)")
    }

    guard let responseText = decoded.response else {
        throw AppError.invalidOllamaResponse
    }

    return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
}

func resolveImageURL(inputFile: String?, rect: RectValues?, saveImagePath: String?) throws -> URL {
    if let inputFile = inputFile {
        let expandedPath = (inputFile as NSString).expandingTildeInPath
        let imageURL = URL(fileURLWithPath: expandedPath)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw AppError.inputFileNotFound(inputFile)
        }
        return imageURL
    }

    let tempPath = "/tmp/ocr.png"
    if let rect = rect {
        _ = ScreenCapture.captureRect(destination: tempPath, x: rect.x, y: rect.y, width: rect.w, height: rect.h)
    } else {
        _ = ScreenCapture.captureRegion(destination: tempPath)
    }

    let imageURL = URL(fileURLWithPath: tempPath)
    guard FileManager.default.fileExists(atPath: imageURL.path) else {
        throw AppError.screenCaptureFailed
    }

    if let saveImagePath = saveImagePath {
        let expandedPath = (saveImagePath as NSString).expandingTildeInPath
        do {
            if FileManager.default.fileExists(atPath: expandedPath) {
                try FileManager.default.removeItem(atPath: expandedPath)
            }
            try FileManager.default.copyItem(atPath: tempPath, toPath: expandedPath)
        } catch {
            fputs("Warning: Could not save image to \(saveImagePath): \(error.localizedDescription)\n", stderr)
        }
    }

    return imageURL
}

func listRecognitionLanguages(for backend: OCRBackend) throws {
    switch backend {
    case .auto:
        print("The auto backend prefers Ollama and falls back to Vision.")
        print("Ollama language support depends on the selected local model.")
        try listRecognitionLanguages(for: .vision)
    case .vision:
        if #available(macOS 11.0, *) {
            let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: .accurate,
                revision: VNRecognizeTextRequestRevision2
            )
            print("Supported Vision OCR languages (accurate):")
            for language in languages {
                print("  \(language)")
            }
        } else {
            print("en-US (language detection requires macOS 11.0+)")
        }
    case .ollama:
        print("The Ollama backend uses the selected model's native language support.")
        print("Choose a vision-capable Ollama model that supports the languages you need.")
    }
}

func makeOllamaConfiguration(arguments: ArgumentParser.Result,
                             modelOption: OptionArgument<String>,
                             hostOption: OptionArgument<String>,
                             promptOption: OptionArgument<String>) throws -> OllamaConfiguration {
    let environment = ProcessInfo.processInfo.environment
    let host = arguments.get(hostOption) ?? environment["OLLAMA_HOST"] ?? defaultOllamaHost
    let prompt = arguments.get(promptOption) ?? environment["OLLAMA_PROMPT"] ?? defaultOllamaPrompt
    let explicitModel = arguments.get(modelOption) ?? environment["OLLAMA_MODEL"]
    let model: String?

    if let explicitModel = explicitModel, !explicitModel.isEmpty {
        model = explicitModel
    } else {
        model = try detectPreferredOllamaModel(host: host)
    }

    guard let model = model, !model.isEmpty else {
        throw AppError.missingOllamaModel
    }

    return OllamaConfiguration(host: host, model: model, prompt: prompt)
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())

    let parser = ArgumentParser(
        usage: "<options>",
        overview: "macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard"
    )

    let backendOption = parser.add(option: "--backend", shortName: "-b", kind: String.self, usage: "OCR backend: auto (default), vision, or ollama")
    let listLanguagesOption = parser.add(option: "--list-languages", kind: Bool.self, usage: "List supported OCR languages for the selected backend")
    let languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set OCR language for Vision, or provide a hint to Ollama")
    let rectOption = parser.add(option: "--rect", shortName: "-R", kind: String.self, usage: "Capture specific region: x,y,width,height (no interactive selection)")
    let inputFileOption = parser.add(option: "--input", shortName: "-i", kind: String.self, usage: "Use image file instead of screen capture")
    let saveImageOption = parser.add(option: "--save-image", shortName: "-s", kind: String.self, usage: "Save captured screenshot to specified path")
    let ollamaModelOption = parser.add(option: "--ollama-model", shortName: "-m", kind: String.self, usage: "Vision-capable Ollama model to use when --backend ollama")
    let ollamaHostOption = parser.add(option: "--ollama-host", kind: String.self, usage: "Ollama server URL (default: http://127.0.0.1:11434)")
    let ollamaPromptOption = parser.add(option: "--ollama-prompt", kind: String.self, usage: "Custom prompt to send to Ollama")

    let parsedArguments = try parser.parse(arguments)
    let backend = try parseBackend(parsedArguments.get(backendOption))

    if parsedArguments.get(listLanguagesOption) == true {
        try listRecognitionLanguages(for: backend)
        exit(EXIT_SUCCESS)
    }

    let rect = try parseRect(parsedArguments.get(rectOption))
    let inputFile = parsedArguments.get(inputFileOption)
    let saveImagePath = parsedArguments.get(saveImageOption)
    let languageHint = parsedArguments.get(languageOption)
    let imageURL = try resolveImageURL(inputFile: inputFile, rect: rect, saveImagePath: saveImagePath)

    let recognizedText: String
    switch backend {
    case .auto:
        do {
            recognizedText = try recognizeTextWithOllama(
                fileURL: imageURL,
                configuration: try makeOllamaConfiguration(
                    arguments: parsedArguments,
                    modelOption: ollamaModelOption,
                    hostOption: ollamaHostOption,
                    promptOption: ollamaPromptOption
                ),
                languageHint: languageHint
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            fputs("Warning: Ollama OCR failed, falling back to Vision: \(message)\n", stderr)
            recognizedText = try recognizeTextWithVision(
                fileURL: imageURL,
                recognitionLanguages: try recognitionLanguagesForVision(languageHint: languageHint)
            )
        }
    case .vision:
        recognizedText = try recognizeTextWithVision(
            fileURL: imageURL,
            recognitionLanguages: try recognitionLanguagesForVision(languageHint: languageHint)
        )
    case .ollama:
        recognizedText = try recognizeTextWithOllama(
            fileURL: imageURL,
            configuration: try makeOllamaConfiguration(
                arguments: parsedArguments,
                modelOption: ollamaModelOption,
                hostOption: ollamaHostOption,
                promptOption: ollamaPromptOption
            ),
            languageHint: languageHint
        )
    }

    emitRecognizedText(recognizedText)
    exit(EXIT_SUCCESS)
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    fputs("Error: \(message)\n", stderr)
    exit(EXIT_FAILURE)
}
