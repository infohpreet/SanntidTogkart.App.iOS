import Foundation

@MainActor
final class SignalRService {
    private let connectionCenter = SignalRConnectionCenter.shared

    static let shared = SignalRService()

    var onMetrics: ((TrainMetrics) -> Void)?
    var onStations: (([TraseStation]) -> Void)?
    var onStationMessages: (([StationMessage]) -> Void)?
    var onTrainStations: (([StationMessage]) -> Void)?
    var onTrainMessages: (([TrainMessage]) -> Void)?
    var onTrainMessage: ((TrainMessage) -> Void)?
    var onLiveTrainMessages: (([TrainMessage]) -> Void)?
    var onTrainRoutePositions: (([TrainPosition]) -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?
    var onError: ((String) -> Void)?

    private let decoder: JSONDecoder

    private static var activeServices: [WeakSignalRServiceBox] = []
    private static var webSocketTask: URLSessionWebSocketTask?
    private static var connectionTask: Task<Void, Never>?
    private static var isStopped = false
    private static var pendingRequests: [PendingRequest] = []
    private static var trainMessagesByID: [String: TrainMessage] = [:]
    private static var liveTrainMessagesByID: [String: TrainMessage] = [:]
    private static var pendingTrainMessageKeys: Set<String> = []
    private static var pendingTrainPositionsByID: [String: TrainPosition] = [:]
    private static var cachedStations: [TraseStation] = []
    private static var cachedTrainMessages: [TrainMessagesCacheKey: [TrainMessage]] = [:]
    private static var cachedMetrics: TrainMetrics?

    init() {
        self.decoder = Self.makeDecoder()
        Self.register(self)
    }

    fileprivate init(configuration: FeedHubSignalRConfiguration) {
        self.decoder = Self.makeDecoder()
        Self.register(self)
    }

    private var configuration: FeedHubSignalRConfiguration {
        .current
    }

    func start() async {
        guard Self.connectionTask == nil else {
            return
        }

        Self.isStopped = false
        Self.connectionTask = Task { [weak self] in
            await self?.runConnectionLoop()
        }
    }

    func stop() {
        Self.isStopped = true
        Self.connectionTask?.cancel()
        Self.connectionTask = nil
        Self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        Self.webSocketTask = nil
        connectionCenter.update(state: .disconnected)
        onStateChange?(.disconnected)
    }

    static func switchEnvironment(to environment: AppEnvironment) async {
        guard AuthConfig.currentEnvironment != environment else {
            return
        }

        AuthConfig.currentEnvironment = environment
        await reloadForCurrentEnvironment()
    }

    static func reloadForCurrentEnvironment() async {
        isStopped = true
        connectionTask?.cancel()
        connectionTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        pendingRequests.removeAll()
        trainMessagesByID.removeAll()
        liveTrainMessagesByID.removeAll()
        pendingTrainMessageKeys.removeAll()
        pendingTrainPositionsByID.removeAll()
        cachedStations.removeAll()
        cachedTrainMessages.removeAll()
        cachedMetrics = nil

        SignalRConnectionCenter.shared.update(state: .disconnected)
        broadcast { service in
            service.onStateChange?(.disconnected)
            service.onStations?([])
            service.onTrainMessages?([])
            service.onLiveTrainMessages?([])
            service.onTrainRoutePositions?([])
        }

        queueRequestsForActiveServices()
        isStopped = false

        guard let service = activeServices.compactMap(\.service).first else {
            return
        }

        await service.start()
    }

    func requestTrainMetrics() async {
        if let cachedMetrics = Self.cachedMetrics {
            onMetrics?(cachedMetrics)
        }

        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingRequests.append(.trainMetrics)
            await start()
            return
        }

        do {
            try await sendGetTrainMetrics(on: webSocketTask)
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func requestStations(filter: String? = nil, forceRefresh: Bool = false) async {
        if !forceRefresh, filter == nil, !Self.cachedStations.isEmpty {
            onStations?(Self.cachedStations)
            return
        }

        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingRequests.append(.stations(filter))
            await start()
            return
        }

        do {
            try await sendGetStations(filter: filter, on: webSocketTask)
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func requestTrainMessages(filter: String? = nil, originDate: Date, forceRefresh: Bool = false) async {
        let cacheKey = TrainMessagesCacheKey(filter: filter ?? "", originDate: dateOnlyFormatter.string(from: originDate))
        if !forceRefresh, let cachedMessages = Self.cachedTrainMessages[cacheKey] {
            onTrainMessages?(cachedMessages)
            return
        }

        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingRequests.append(.trainMessages(filter, originDate))
            await start()
            return
        }

        do {
            try await sendGetTrainMessages(filter: filter, originDate: originDate, on: webSocketTask)
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func requestTrainPositionsList(
        countryCode: String,
        trainNumber: String,
        originDate: String
    ) async {
        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingRequests.append(.trainPositionsList(countryCode, trainNumber, originDate))
            await start()
            return
        }

        do {
            try await sendGetTrainPositionsList(
                countryCode: countryCode,
                trainNumber: trainNumber,
                originDate: originDate,
                on: webSocketTask
            )
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func requestTrainMessage(
        countryCode: String,
        trainNo: String,
        originDate: String
    ) async {
        let key = trainMessageKey(countryCode: countryCode, trainNo: trainNo, originDate: originDate)
        if let cachedTrainMessage = Self.trainMessagesByID[key] {
            onTrainMessage?(cachedTrainMessage)
            return
        }

        guard !Self.pendingTrainMessageKeys.contains(key) else {
            return
        }

        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingTrainMessageKeys.insert(key)
            Self.pendingRequests.append(.trainMessage(countryCode, trainNo, originDate))
            await start()
            return
        }

        do {
            Self.pendingTrainMessageKeys.insert(key)
            try await sendGetTrainMessage(
                countryCode: countryCode,
                trainNo: trainNo,
                originDate: originDate,
                on: webSocketTask
            )
        } catch {
            Self.pendingTrainMessageKeys.remove(key)
            onError?(error.localizedDescription)
        }
    }

    func requestTrainStations(
        countryCode: String,
        trainNumber: String,
        originDate: String
    ) async {
        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingRequests.append(.trainStations(countryCode, trainNumber, originDate))
            await start()
            return
        }

        do {
            try await sendGetTrainStations(
                countryCode: countryCode,
                trainNumber: trainNumber,
                originDate: originDate,
                on: webSocketTask
            )
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func requestStationMessages(
        countryCode: String,
        stationShortName: String,
        originDate: String
    ) async {
        guard let webSocketTask = Self.webSocketTask else {
            Self.pendingRequests.append(.stationMessages(countryCode, stationShortName, originDate))
            await start()
            return
        }

        do {
            try await sendGetStationMessages(
                countryCode: countryCode,
                stationShortName: stationShortName,
                originDate: originDate,
                on: webSocketTask
            )
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func runConnectionLoop() async {
        while !Task.isCancelled && !Self.isStopped {
            do {
                try await connect()
                return
            } catch is CancellationError {
                return
            } catch {
                guard !Self.isStopped, !Task.isCancelled else {
                    return
                }

                connectionCenter.update(state: .failed, details: error.localizedDescription)
                onStateChange?(.failed)
                onError?(error.localizedDescription)

                onStateChange?(.reconnecting)
                connectionCenter.update(state: .reconnecting)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func connect() async throws {
        connectionCenter.update(state: .connecting)
        onStateChange?(.connecting)

        let accessToken = try await fetchAccessToken()
        let negotiation = try await negotiate(accessToken: accessToken)
        let connectionID = negotiation.connectionToken ?? negotiation.connectionId

        guard let connectionID else {
            throw SignalRServiceError.invalidNegotiationResponse
        }

        var webSocketRequest = URLRequest(url: try webSocketURL(connectionID: connectionID))
        webSocketRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let webSocketTask = URLSession.shared.webSocketTask(with: webSocketRequest)
        Self.webSocketTask = webSocketTask
        webSocketTask.resume()

        try await sendHandshake(on: webSocketTask)
        connectionCenter.update(state: .connected)
        onStateChange?(.connected)
        try await sendGetTrainMetrics(on: webSocketTask)
        try await flushPendingRequests(on: webSocketTask)
        try await receiveLoop(on: webSocketTask)
    }

    private func fetchAccessToken() async throws -> String {
        var lastError: Error?

        for scope in configuration.tokenScopes {
            do {
                return try await requestAccessToken(scope: scope)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? SignalRServiceError.failedToFetchAccessToken
    }

    private func requestAccessToken(scope: String) async throws -> String {
        let tokenURL = URL(string: "https://login.microsoftonline.com/\(configuration.azureTenantID)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            "client_id": configuration.azureClientID,
            "client_secret": configuration.azureClientSecret,
            "grant_type": "client_credentials",
            "scope": scope
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let tokenResponse = try decoder.decode(AzureTokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    private func negotiate(accessToken: String) async throws -> SignalRNegotiationResponse {
        var components = URLComponents(url: configuration.hubURL.appending(path: "negotiate"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "negotiateVersion", value: "1")]

        guard let negotiateURL = components?.url else {
            throw SignalRServiceError.invalidHubURL
        }

        var request = URLRequest(url: negotiateURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        return try decoder.decode(SignalRNegotiationResponse.self, from: data)
    }

    private func webSocketURL(connectionID: String) throws -> URL {
        guard var components = URLComponents(url: configuration.hubURL, resolvingAgainstBaseURL: false) else {
            throw SignalRServiceError.invalidHubURL
        }

        switch components.scheme {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        default:
            break
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "id", value: connectionID))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw SignalRServiceError.invalidHubURL
        }

        return url
    }

    private func sendHandshake(on webSocketTask: URLSessionWebSocketTask) async throws {
        try await send(text: #"{"protocol":"json","version":1}"#, on: webSocketTask)
    }

    private func sendGetTrainMetrics(on webSocketTask: URLSessionWebSocketTask) async throws {
        try await sendInvocation(
            invocationID: "get-train-metrics",
            target: "GetTrainMetrics",
            arguments: [],
            on: webSocketTask
        )
    }

    private func sendGetStations(filter: String?, on webSocketTask: URLSessionWebSocketTask) async throws {
        try await sendInvocation(
            invocationID: "get-stations",
            target: "GetStations",
            arguments: [.string(filter ?? "")],
            on: webSocketTask
        )
    }

    private func sendGetTrainMessages(
        filter: String?,
        originDate: Date,
        on webSocketTask: URLSessionWebSocketTask
    ) async throws {
        try await sendInvocation(
            invocationID: "get-train-messages",
            target: "GetTrainMessages",
            arguments: [
                .string(filter ?? ""),
                .string(dateOnlyFormatter.string(from: originDate))
            ],
            on: webSocketTask
        )
    }

    private func sendGetTrainPositionsList(
        countryCode: String,
        trainNumber: String,
        originDate: String,
        on webSocketTask: URLSessionWebSocketTask
    ) async throws {
        try await sendInvocation(
            invocationID: "get-train-positions-list",
            target: "GetTrainPositionsList",
            arguments: [
                .string(countryCode),
                .string(trainNumber),
                .string(originDate)
            ],
            on: webSocketTask
        )
    }

    private func sendGetTrainMessage(
        countryCode: String,
        trainNo: String,
        originDate: String,
        on webSocketTask: URLSessionWebSocketTask
    ) async throws {
        try await sendInvocation(
            invocationID: "get-train-message-\(countryCode)-\(trainNo)-\(originDate)",
            target: "GetTrainMessage",
            arguments: [
                .string(countryCode),
                .string(trainNo),
                .string(originDate)
            ],
            on: webSocketTask
        )
    }

    private func sendGetTrainStations(
        countryCode: String,
        trainNumber: String,
        originDate: String,
        on webSocketTask: URLSessionWebSocketTask
    ) async throws {
        try await sendInvocation(
            invocationID: "get-train-stations-\(countryCode)-\(trainNumber)-\(originDate)",
            target: "GetTrainStations",
            arguments: [
                .string(countryCode),
                .string(trainNumber),
                .string(originDate)
            ],
            on: webSocketTask
        )
    }

    private func sendGetStationMessages(
        countryCode: String,
        stationShortName: String,
        originDate: String,
        on webSocketTask: URLSessionWebSocketTask
    ) async throws {
        try await sendInvocation(
            invocationID: "get-station-messages-\(countryCode)-\(stationShortName)-\(originDate)",
            target: "GetStationMessages",
            arguments: [
                .string(countryCode),
                .string(stationShortName),
                .string(originDate)
            ],
            on: webSocketTask
        )
    }

    private func sendInvocation(
        invocationID: String,
        target: String,
        arguments: [SignalRArgument],
        on webSocketTask: URLSessionWebSocketTask
    ) async throws {
        let payload = SignalRInvocationMessage(
            type: 1,
            invocationId: invocationID,
            target: target,
            arguments: arguments
        )
        let data = try JSONEncoder().encode(payload)

        guard let text = String(data: data, encoding: .utf8) else {
            throw SignalRServiceError.invalidInvocationPayload
        }

        try await send(text: text, on: webSocketTask)
    }

    private func send(text: String, on webSocketTask: URLSessionWebSocketTask) async throws {
        try await webSocketTask.send(.string(text + String(recordSeparator)))
    }

    private func flushPendingRequests(on webSocketTask: URLSessionWebSocketTask) async throws {
        let requests = Self.pendingRequests
        Self.pendingRequests.removeAll()

        for request in requests {
            switch request {
            case .trainMetrics:
                try await sendGetTrainMetrics(on: webSocketTask)
            case .stations(let filter):
                try await sendGetStations(filter: filter, on: webSocketTask)
            case .trainMessages(let filter, let originDate):
                try await sendGetTrainMessages(filter: filter, originDate: originDate, on: webSocketTask)
            case .trainPositionsList(let countryCode, let trainNumber, let originDate):
                try await sendGetTrainPositionsList(
                    countryCode: countryCode,
                    trainNumber: trainNumber,
                    originDate: originDate,
                    on: webSocketTask
                )
            case .trainMessage(let countryCode, let trainNo, let originDate):
                try await sendGetTrainMessage(
                    countryCode: countryCode,
                    trainNo: trainNo,
                    originDate: originDate,
                    on: webSocketTask
                )
            case .trainStations(let countryCode, let trainNumber, let originDate):
                try await sendGetTrainStations(
                    countryCode: countryCode,
                    trainNumber: trainNumber,
                    originDate: originDate,
                    on: webSocketTask
                )
            case .stationMessages(let countryCode, let stationShortName, let originDate):
                try await sendGetStationMessages(
                    countryCode: countryCode,
                    stationShortName: stationShortName,
                    originDate: originDate,
                    on: webSocketTask
                )
            }
        }
    }

    private func receiveLoop(on webSocketTask: URLSessionWebSocketTask) async throws {
        while !Task.isCancelled && !Self.isStopped {
            let message = try await webSocketTask.receive()
            try handle(message: message)
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) throws {
        let rawText: String

        switch message {
        case .string(let text):
            rawText = text
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw SignalRServiceError.invalidMessageEncoding
            }
            rawText = text
        @unknown default:
            throw SignalRServiceError.unsupportedWebSocketMessage
        }

        let payloads = rawText.split(separator: recordSeparator, omittingEmptySubsequences: true)
        for payload in payloads {
            try handle(payload: String(payload))
        }
    }

    private func handle(payload: String) throws {
        guard !payload.isEmpty else {
            return
        }

        let data = Data(payload.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let json = jsonObject as? [String: Any] else {
            return
        }

        guard let messageType = json["type"] as? Int else {
            return
        }

        switch messageType {
        case 1:
            guard let target = json["target"] as? String else {
                return
            }

            guard
                let arguments = json["arguments"] as? [Any],
                let firstArgument = arguments.first
            else {
                throw SignalRServiceError.invalidInvocationArguments
            }

            let argumentData = try JSONSerialization.data(withJSONObject: firstArgument)

            switch target {
            case "ReceiveTrainMetrics":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let metrics = try decoder.decode(TrainMetrics.self, from: argumentData)
                        await MainActor.run {
                            Self.cachedMetrics = metrics
                            Self.broadcast { $0.onMetrics?(metrics) }
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveTrainMetrics", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveStations":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let stations = try decoder.decode([TraseStation].self, from: argumentData)
                        await MainActor.run {
                            Self.cachedStations = stations
                            Self.broadcast { $0.onStations?(stations) }
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveStations", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveTrainMessages":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let trainMessages = try decoder.decode([TrainMessage].self, from: argumentData)
                        await MainActor.run {
                            let cachedMessages = self.cacheTrainMessages(trainMessages)
                            if let cacheKey = self.trainMessagesCacheKey(from: cachedMessages) {
                                Self.cachedTrainMessages[cacheKey] = cachedMessages
                            }
                            Self.broadcast { $0.onTrainMessages?(cachedMessages) }
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveTrainMessages", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveTrainStations":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let stationMessages = try decoder.decode([StationMessage].self, from: argumentData)
                        await MainActor.run {
                            Self.broadcast { $0.onTrainStations?(stationMessages) }
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveTrainStations", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveStationMessages":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let stationMessages = try decoder.decode([StationMessage].self, from: argumentData)
                        await MainActor.run {
                            Self.broadcast { $0.onStationMessages?(stationMessages) }
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveStationMessages", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveTrainMessage":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let trainMessage = try await MainActor.run {
                            try decoder.decode(TrainMessage.self, from: argumentData)
                        }
                        await MainActor.run {
                            _ = self.cacheTrainMessages([trainMessage])
                            Self.broadcast { $0.onTrainMessage?(trainMessage) }
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveTrainMessage", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveTrainPosition":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let trainPosition = try await MainActor.run {
                            try decoder.decode(TrainPosition.self, from: argumentData)
                        }
                        await MainActor.run {
                            self.handleTrainPosition(trainPosition)
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveTrainPosition", error: error, data: argumentData)
                        }
                    }
                }
            case "ReceiveTrainPositionList":
                let decoder = self.decoder
                Task.detached(priority: .userInitiated) {
                    do {
                        let trainPositions = try decoder.decode([TrainPosition].self, from: argumentData)
                        await MainActor.run {
                            self.handleTrainPositionList(trainPositions)
                        }
                    } catch {
                        await MainActor.run {
                            self.logDecodingFailure(prefix: "SignalR ReceiveTrainPositionList", error: error, data: argumentData)
                        }
                    }
                }
            default:
                return
            }
        case 6:
            return
        case 7:
            let serverError = json["error"] as? String ?? "SignalR-tilkoblingen ble lukket av serveren."
            connectionCenter.update(state: .failed, details: serverError)
            throw SignalRServiceError.serverClosed(serverError)
        default:
            return
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignalRServiceError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Ukjent serverrespons"
            throw SignalRServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func formEncodedBody(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private var recordSeparator: Character {
        "\u{1e}"
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { codingPath in
            let lastKey = codingPath.last!
            let stringValue = lastKey.stringValue
            guard let firstCharacter = stringValue.first else {
                return lastKey
            }

            let normalizedKey = firstCharacter.lowercased() + stringValue.dropFirst()
            return AnyCodingKey(stringValue: normalizedKey) ?? lastKey
        }
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = extendedFractionalDateFormatter.date(from: value) {
                return date
            }

            if let date = fractionalISO8601Formatter.date(from: value) {
                return date
            }

            if let date = iso8601Formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        return decoder
    }

    private func handleTrainPosition(_ trainPosition: TrainPosition) {
        let key = liveTrainPositionKey(for: trainPosition)
        if let existingMessage = Self.liveTrainMessagesByID[key] ?? Self.trainMessagesByID[key] {
            let updatedMessage = mergedTrainMessage(existingMessage, with: trainPosition)
            Self.trainMessagesByID[key] = updatedMessage
            Self.liveTrainMessagesByID[key] = updatedMessage
            Self.pendingTrainPositionsByID.removeValue(forKey: key)
            publishLiveTrainMessages()
            return
        }

        Self.pendingTrainPositionsByID[key] = trainPosition
        requestMissingTrainMessage(for: trainPosition)
    }

    private func handleTrainPositionList(_ trainPositions: [TrainPosition]) {
        for trainPosition in trainPositions {
            requestMissingTrainMessage(for: trainPosition)
        }

        Self.broadcast { $0.onTrainRoutePositions?(trainPositions) }
    }

    private func logDecodingFailure(prefix: String, error: Error, data: Data) {
        print("\(prefix) decode error:", error)
        print("\(prefix) decode details:", decodingErrorDescription(error))
        if let rawPayload = String(data: data, encoding: .utf8) {
            print("\(prefix) raw payload:", rawPayload)
        }
    }

    private func decodingErrorDescription(_ error: Error) -> String {
        switch error {
        case let DecodingError.keyNotFound(key, context):
            return "keyNotFound(\(key.stringValue)) path=\(codingPathDescription(context.codingPath)) description=\(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            return "valueNotFound(\(type)) path=\(codingPathDescription(context.codingPath)) description=\(context.debugDescription)"
        case let DecodingError.typeMismatch(type, context):
            return "typeMismatch(\(type)) path=\(codingPathDescription(context.codingPath)) description=\(context.debugDescription)"
        case let DecodingError.dataCorrupted(context):
            return "dataCorrupted path=\(codingPathDescription(context.codingPath)) description=\(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }

    private func codingPathDescription(_ codingPath: [CodingKey]) -> String {
        let path = codingPath.map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }
            return key.stringValue
        }
        return path.isEmpty ? "<root>" : path.joined(separator: ".")
    }

    private func requestMissingTrainMessage(for trainPosition: TrainPosition) {
        guard
            let originDate = normalizedOriginDate(
                trainPosition.geoJson.properties.originDate,
                fallbackDate: trainPosition.geoJson.properties.serviceTime
            ),
            !trainPosition.geoJson.properties.trainNumber.isEmpty
        else {
            return
        }

        Task { [weak self] in
            await self?.requestTrainMessage(
                countryCode: trainPosition.country,
                trainNo: trainPosition.geoJson.properties.trainNumber,
                originDate: originDate
            )
        }
    }

    private func cacheTrainMessages(_ trainMessages: [TrainMessage]) -> [TrainMessage] {
        var cachedMessages: [TrainMessage] = []
        var shouldPublishLiveMessages = false

        for trainMessage in trainMessages {
            let key = trainMessageKey(
                countryCode: trainMessage.countryCode,
                trainNo: trainMessage.trainNo,
                originDate: trainMessage.originDate
            )
            let latestTrainPosition = Self.pendingTrainPositionsByID[key]
                ?? Self.liveTrainMessagesByID[key]?.trainPosition
                ?? Self.trainMessagesByID[key]?.trainPosition
            let mergedMessage = mergedTrainMessage(trainMessage, with: latestTrainPosition)

            Self.trainMessagesByID[key] = mergedMessage
            Self.pendingTrainMessageKeys.remove(key)

            if mergedMessage.trainPosition != nil {
                Self.liveTrainMessagesByID[key] = mergedMessage
                Self.pendingTrainPositionsByID.removeValue(forKey: key)
                shouldPublishLiveMessages = true
            }

            cachedMessages.append(mergedMessage)
        }

        if shouldPublishLiveMessages {
            publishLiveTrainMessages()
        }

        return cachedMessages
    }

    private func liveTrainPositionKey(for trainPosition: TrainPosition) -> String {
        let originDate = normalizedOriginDate(
            trainPosition.geoJson.properties.originDate,
            fallbackDate: trainPosition.geoJson.properties.serviceTime
        ) ?? "unknown-date"
        return "\(trainPosition.country)-\(trainPosition.geoJson.properties.trainNumber)-\(originDate)"
    }

    private func publishLiveTrainMessages() {
        let liveTrainMessages = Self.liveTrainMessagesByID.values
            .filter { $0.trainPosition != nil }
            .sorted { lhs, rhs in
                lhs.messageKey.localizedStandardCompare(rhs.messageKey) == .orderedAscending
            }

        Self.broadcast { $0.onLiveTrainMessages?(liveTrainMessages) }
    }

    private func mergedTrainMessage(_ trainMessage: TrainMessage, with trainPosition: TrainPosition?) -> TrainMessage {
        TrainMessage(
            id: trainMessage.id,
            countryCode: trainMessage.countryCode,
            messageKey: trainMessage.messageKey,
            advertisementTrainNo: trainMessage.advertisementTrainNo,
            trainNo: trainMessage.trainNo,
            originDate: trainMessage.originDate,
            originTime: trainMessage.originTime,
            origin: trainMessage.origin,
            destination: trainMessage.destination,
            trainType: trainMessage.trainType,
            lineNumber: trainMessage.lineNumber,
            company: trainMessage.company,
            scheduled: trainMessage.scheduled,
            trainPosition: trainPosition,
            createdAt: trainMessage.createdAt,
            lastUpdatedAt: trainMessage.lastUpdatedAt
        )
    }

    private func trainMessageKey(countryCode: String, trainNo: String, originDate: String) -> String {
        "\(countryCode)-\(trainNo)-\(originDate)"
    }

    private func trainMessagesCacheKey(from trainMessages: [TrainMessage]) -> TrainMessagesCacheKey? {
        guard let first = trainMessages.first else {
            return nil
        }

        return TrainMessagesCacheKey(filter: "", originDate: first.originDate)
    }

    private func normalizedOriginDate(_ originDate: String?, fallbackDate: Date? = nil) -> String? {
        let value = originDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty {
            return value
        }

        guard let fallbackDate else {
            return nil
        }

        return dateOnlyFormatter.string(from: fallbackDate)
    }

    private static func register(_ service: SignalRService) {
        activeServices.removeAll { $0.service == nil }
        activeServices.append(WeakSignalRServiceBox(service))
    }

    private static func broadcast(_ action: (SignalRService) -> Void) {
        activeServices.removeAll { $0.service == nil }
        for box in activeServices {
            if let service = box.service {
                action(service)
            }
        }
    }

    private static func queueRequestsForActiveServices() {
        activeServices.removeAll { $0.service == nil }

        if activeServices.contains(where: { $0.service?.onMetrics != nil }) {
            pendingRequests.append(.trainMetrics)
        }

        if activeServices.contains(where: { serviceBox in
            guard let service = serviceBox.service else {
                return false
            }

            return service.onStations != nil || service.onLiveTrainMessages != nil
        }) {
            pendingRequests.append(.stations(nil))
        }

        if activeServices.contains(where: { $0.service?.onTrainMessages != nil }) {
            pendingRequests.append(.trainMessages("", Date()))
        }
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private enum PendingRequest {
    case trainMetrics
    case stations(String?)
    case stationMessages(String, String, String)
    case trainMessages(String?, Date)
    case trainPositionsList(String, String, String)
    case trainMessage(String, String, String)
    case trainStations(String, String, String)
}

private struct TrainMessagesCacheKey: Hashable {
    let filter: String
    let originDate: String
}

private final class WeakSignalRServiceBox {
    weak var service: SignalRService?

    init(_ service: SignalRService) {
        self.service = service
    }
}

private let iso8601Formatter = ISO8601DateFormatter()

private let fractionalISO8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let extendedFractionalDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
    return formatter
}()

private let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private struct FeedHubSignalRConfiguration {
    let hubURL: URL
    let azureClientID: String
    let azureTenantID: String
    let azureClientSecret: String
    let tokenScopes: [String]

    static var current: FeedHubSignalRConfiguration {
        FeedHubSignalRConfiguration(
        hubURL: AuthConfig.hubURL,
        azureClientID: AuthConfig.azureClientID,
        azureTenantID: AuthConfig.azureTenantID,
        azureClientSecret: AuthConfig.azureClientSecret,
        tokenScopes: [
            "api://\(AuthConfig.azureClientID)/.default"
        ]
        )
    }
}

private struct AzureTokenResponse: Decodable {
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct SignalRNegotiationResponse: Decodable {
    let connectionId: String?
    let connectionToken: String?
}

private struct SignalRInvocationMessage: Encodable {
    let type: Int
    let invocationId: String
    let target: String
    let arguments: [SignalRArgument]
}

private enum SignalRArgument: Encodable {
    case string(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        }
    }
}

private enum SignalRServiceError: LocalizedError {
    case failedToFetchAccessToken
    case httpError(statusCode: Int, message: String)
    case invalidHTTPResponse
    case invalidHubURL
    case invalidInvocationArguments
    case invalidInvocationPayload
    case invalidMessageEncoding
    case invalidNegotiationResponse
    case serverClosed(String)
    case unsupportedWebSocketMessage

    var errorDescription: String? {
        switch self {
        case .failedToFetchAccessToken:
            return "Kunne ikke hente access token fra Azure."
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .invalidHTTPResponse:
            return "Ugyldig HTTP-respons fra serveren."
        case .invalidHubURL:
            return "Hub-URL-en er ugyldig."
        case .invalidInvocationArguments:
            return "SignalR-responsen mangler gyldige arguments."
        case .invalidInvocationPayload:
            return "Kunne ikke bygge SignalR-invocation payload."
        case .invalidMessageEncoding:
            return "Kunne ikke lese WebSocket-meldingen som tekst."
        case .invalidNegotiationResponse:
            return "SignalR negotiate-responsen mangler connection-id."
        case .serverClosed(let message):
            return message
        case .unsupportedWebSocketMessage:
            return "Mottok en WebSocket-melding appen ikke støtter."
        }
    }
}
