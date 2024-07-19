import Foundation

enum GrantType: String {
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
    case anonymous = "urn:authgear:params:oauth:grant-type:anonymous-request"
    case biometric = "urn:authgear:params:oauth:grant-type:biometric-request"
    case idToken = "urn:authgear:params:oauth:grant-type:id-token"
    case app2app = "urn:authgear:params:oauth:grant-type:app2app-request"
    case settingsAction = "urn:authgear:params:oauth:grant-type:settings-action"
    case tokenExchange = "urn:ietf:params:oauth:grant-type:token-exchange"
}

enum RequestedTokenType: String {
    case appInitiatedSSOToWebToken = "urn:authgear:params:oauth:token-type:app-initiated-sso-to-web-token"
}

enum SubjectTokenType: String {
    case idToken = "urn:ietf:params:oauth:token-type:id_token"
}

enum ActorTokenType: String {
    case deviceSecret = "urn:x-oath:params:oauth:token-type:device-secret"
}

enum ResponseType: String {
    case code
    case settingsAction = "urn:authgear:params:oauth:response-type:settings-action"
    case none
    case appInitiatedSSOToWebToken = "urn:authgear:params:oauth:response-type:app_initiated_sso_to_web token"
}

struct APIResponse<T: Decodable>: Decodable {
    let result: T

    func toResult() -> Result<T, Error> {
        .success(result)
    }
}

struct APIErrorResponse: Decodable {
    let error: ServerError
}

struct OIDCAuthenticationRequest {
    let redirectURI: String
    let responseType: String
    let scope: [String]?
    let isSSOEnabled: Bool?
    let state: String?
    let xState: String?
    let prompt: [PromptOption]?
    let loginHint: String?
    let uiLocales: [String]?
    let colorScheme: ColorScheme?
    let idTokenHint: String?
    let maxAge: Int?
    let wechatRedirectURI: String?
    let page: AuthenticationPage?
    let settingsAction: SettingsAction?
    let authenticationFlowGroup: String?
    let responseMode: String?
    let xAppInitiatedSSOToWebToken: String?

    func toQueryItems(clientID: String, verifier: CodeVerifier?) -> [URLQueryItem] {
        var queryItems = [
            URLQueryItem(name: "response_type", value: self.responseType),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: self.redirectURI),
            URLQueryItem(name: "x_platform", value: "ios")
        ]
        
        if let scope = scope {
            queryItems.append(URLQueryItem(
                name: "scope",
                value: scope.joined(separator: " ")
            ))
        }

        if let verifier = verifier {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "code_challenge_method", value: Authgear.CodeChallengeMethod),
                URLQueryItem(name: "code_challenge", value: verifier.codeChallenge)
            ])
        }

        if let state = self.state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if let xState = self.xState {
            queryItems.append(URLQueryItem(name: "x_state", value: xState))
        }

        if let prompt = self.prompt {
            queryItems.append(URLQueryItem(name: "prompt", value: prompt.map { $0.rawValue }.joined(separator: " ")))
        }

        if let loginHint = self.loginHint {
            queryItems.append(URLQueryItem(name: "login_hint", value: loginHint))
        }

        if let idTokenHint = self.idTokenHint {
            queryItems.append(URLQueryItem(name: "id_token_hint", value: idTokenHint))
        }

        if let uiLocales = self.uiLocales {
            queryItems.append(URLQueryItem(
                name: "ui_locales",
                value: UILocales.stringify(uiLocales: uiLocales)
            ))
        }

        if let colorScheme = colorScheme {
            queryItems.append(URLQueryItem(
                name: "x_color_scheme",
                value: colorScheme.rawValue
            ))
        }

        if let maxAge = self.maxAge {
            queryItems.append(URLQueryItem(
                name: "max_age",
                value: String(format: "%d", maxAge)
            ))
        }

        if let wechatRedirectURI = self.wechatRedirectURI {
            queryItems.append(URLQueryItem(
                name: "x_wechat_redirect_uri",
                value: wechatRedirectURI
            ))
        }

        if let page = self.page {
            queryItems.append(URLQueryItem(name: "x_page", value: page.rawValue))
        }

        if let settingsAction = self.settingsAction {
            queryItems.append(URLQueryItem(name: "x_settings_action", value: settingsAction.rawValue))
        }
        
        if let responseMode = self.responseMode {
            queryItems.append(URLQueryItem(name: "response_mode", value: responseMode))
        }
        
        if let xAppInitiatedSSOToWebToken = self.xAppInitiatedSSOToWebToken {
            queryItems.append(URLQueryItem(name: "x_app_initiated_sso_to_web_token", value: xAppInitiatedSSOToWebToken))
        }
        
        if let isSSOEnabled = self.isSSOEnabled {
            if isSSOEnabled == false {
                // For backward compatibility
                // If the developer updates the SDK but not the server
                queryItems.append(URLQueryItem(name: "x_suppress_idp_session_cookie", value: "true"))
            }
            queryItems.append(URLQueryItem(name: "x_sso_enabled", value: isSSOEnabled ? "true" : "false"))
        }

        if let authenticationFlowGroup = self.authenticationFlowGroup {
            queryItems.append(URLQueryItem(name: "x_authentication_flow_group", value: authenticationFlowGroup))
        }

        return queryItems
    }
}

struct OIDCTokenResponse: Decodable {
    let idToken: String?
    let tokenType: String?
    let accessToken: String?
    let expiresIn: Int?
    let refreshToken: String?
    let deviceSecret: String?
    let code: String?
}

struct ChallengeBody: Encodable {
    let purpose: String
}

struct ChallengeResponse: Decodable {
    let token: String
    let expireAt: String
}

struct AppSessionTokenBody: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct AppSessionTokenResponse: Decodable {
    let appSessionToken: String
    let expireAt: String
}

protocol AuthAPIClient: AnyObject {
    var endpoint: URL { get }
    func makeAuthgearURL(path: String, handler: @escaping (Result<URL, Error>) -> Void)
    func fetchOIDCConfiguration(handler: @escaping (Result<OIDCConfiguration, Error>) -> Void)
    func requestOIDCToken(
        grantType: GrantType,
        clientId: String,
        deviceInfo: DeviceInfoRoot?,
        redirectURI: String?,
        code: String?,
        codeVerifier: String?,
        codeChallenge: String?,
        codeChallengeMethod: String?,
        refreshToken: String?,
        jwt: String?,
        accessToken: String?,
        xApp2AppDeviceKeyJwt: String?,
        scope: [String]?,
        requestedTokenType: RequestedTokenType?,
        subjectTokenType: SubjectTokenType?,
        subjectToken: String?,
        actorTokenType: ActorTokenType?,
        actorToken: String?,
        audience: String?,
        deviceSecret: String?,
        handler: @escaping (Result<OIDCTokenResponse, Error>) -> Void
    )
    func requestBiometricSetup(
        clientId: String,
        accessToken: String,
        jwt: String,
        handler: @escaping (Result<Void, Error>) -> Void
    )
    func requestOIDCUserInfo(
        accessToken: String,
        handler: @escaping (Result<UserInfo, Error>) -> Void
    )
    func requestOIDCRevocation(
        refreshToken: String,
        handler: @escaping (Result<Void, Error>) -> Void
    )
    func requestOAuthChallenge(
        purpose: String,
        handler: @escaping (Result<ChallengeResponse, Error>) -> Void
    )
    func requestAppSessionToken(
        refreshToken: String,
        handler: @escaping (Result<AppSessionTokenResponse, Error>) -> Void
    )
    func requestWechatAuthCallback(
        code: String,
        state: String,
        handler: @escaping (Result<Void, Error>) -> Void
    )
}

extension AuthAPIClient {
    private func withSemaphore<T>(
        asynTask: (@escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)

        var returnValue: Result<T, Error>?
        asynTask { result in
            returnValue = result
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .distantFuture)
        return try returnValue!.get()
    }

    func syncFetchOIDCConfiguration() throws -> OIDCConfiguration {
        try withSemaphore { handler in
            self.fetchOIDCConfiguration(handler: handler)
        }
    }

    func syncRequestOIDCToken(
        grantType: GrantType,
        clientId: String,
        deviceInfo: DeviceInfoRoot?,
        redirectURI: String?,
        code: String?,
        codeVerifier: String?,
        codeChallenge: String?,
        codeChallengeMethod: String?,
        refreshToken: String?,
        jwt: String?,
        accessToken: String?,
        xApp2AppDeviceKeyJwt: String?,
        scope: [String]?,
        requestedTokenType: RequestedTokenType?,
        subjectTokenType: SubjectTokenType?,
        subjectToken: String?,
        actorTokenType: ActorTokenType?,
        actorToken: String?,
        audience: String?,
        deviceSecret: String?
    ) throws -> OIDCTokenResponse {
        try withSemaphore { handler in
            self.requestOIDCToken(
                grantType: grantType,
                clientId: clientId,
                deviceInfo: deviceInfo,
                redirectURI: redirectURI,
                code: code,
                codeVerifier: codeVerifier,
                codeChallenge: codeChallenge,
                codeChallengeMethod: codeChallengeMethod,
                refreshToken: refreshToken,
                jwt: jwt,
                accessToken: accessToken,
                xApp2AppDeviceKeyJwt: xApp2AppDeviceKeyJwt,
                scope: scope,
                requestedTokenType: requestedTokenType,
                subjectTokenType: subjectTokenType,
                subjectToken: subjectToken,
                actorTokenType: actorTokenType,
                actorToken: actorToken,
                audience: audience,
                deviceSecret: deviceSecret,
                handler: handler
            )
        }
    }

    func syncRequestBiometricSetup(
        clientId: String,
        accessToken: String,
        jwt: String
    ) throws {
        try withSemaphore { handler in
            self.requestBiometricSetup(
                clientId: clientId,
                accessToken: accessToken,
                jwt: jwt,
                handler: handler
            )
        }
    }

    func syncRequestOIDCUserInfo(
        accessToken: String
    ) throws -> UserInfo {
        try withSemaphore { handler in
            self.requestOIDCUserInfo(
                accessToken: accessToken,
                handler: handler
            )
        }
    }

    func syncRequestOIDCRevocation(
        refreshToken: String
    ) throws {
        try withSemaphore { handler in
            self.requestOIDCRevocation(
                refreshToken: refreshToken,
                handler: handler
            )
        }
    }

    func syncRequestOAuthChallenge(
        purpose: String
    ) throws -> ChallengeResponse {
        try withSemaphore { handler in
            self.requestOAuthChallenge(
                purpose: purpose,
                handler: handler
            )
        }
    }

    func syncRequestAppSessionToken(
        refreshToken: String
    ) throws -> AppSessionTokenResponse {
        try withSemaphore { handler in
            self.requestAppSessionToken(
                refreshToken: refreshToken,
                handler: handler
            )
        }
    }

    func syncRequestWechatAuthCallback(code: String, state: String) throws {
        try withSemaphore { handler in
            self.requestWechatAuthCallback(
                code: code, state: state,
                handler: handler
            )
        }
    }
}

func authgearFetch(
    urlSession: URLSession,
    request: URLRequest,
    handler: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void
) {
    let dataTaslk = urlSession.dataTask(with: request) { data, response, error in
        if let error = error {
            return handler(.failure(wrapError(error: error)))
        }

        let response = response as! HTTPURLResponse

        if response.statusCode < 200 || response.statusCode >= 300 {
            if let data = data {
                let decorder = JSONDecoder()
                decorder.keyDecodingStrategy = .convertFromSnakeCase
                if let error = try? decorder.decode(OAuthError.self, from: data) {
                    return handler(.failure(AuthgearError.oauthError(error)))
                }
                if let errorResp = try? decorder.decode(APIErrorResponse.self, from: data) {
                    return handler(.failure(AuthgearError.serverError(errorResp.error)))
                }
            }
            return handler(.failure(AuthgearError.unexpectedHttpStatusCode(response.statusCode, data)))
        }

        return handler(.success((data, response)))
    }

    dataTaslk.resume()
}

class DefaultAuthAPIClient: AuthAPIClient {
    public let endpoint: URL

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    private let defaultSession = URLSession(configuration: .default)
    private var oidcConfiguration: OIDCConfiguration?

    private func buildFetchOIDCConfigurationRequest() -> URLRequest {
        URLRequest(url: endpoint.appendingPathComponent("/.well-known/openid-configuration"))
    }

    func fetchOIDCConfiguration(handler: @escaping (Result<OIDCConfiguration, Error>) -> Void) {
        if let configuration = oidcConfiguration {
            return handler(.success(configuration))
        }

        let request = buildFetchOIDCConfigurationRequest()

        fetch(request: request) { [weak self] (result: Result<OIDCConfiguration, Error>) in
            self?.oidcConfiguration = try? result.get()
            return handler(result)
        }
    }

    func fetch<T: Decodable>(
        request: URLRequest,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase,
        handler: @escaping (Result<T, Error>) -> Void
    ) {
        authgearFetch(urlSession: defaultSession, request: request) { result in
            handler(result.flatMap { (data, _) -> Result<T, Error> in
                do {
                    let decorder = JSONDecoder()
                    decorder.keyDecodingStrategy = keyDecodingStrategy
                    let response = try decorder.decode(T.self, from: data!)
                    return .success(response)
                } catch {
                    return .failure(wrapError(error: error))
                }
            })
        }
    }

    func makeAuthgearURL(path: String, handler: @escaping (Result<URL, Error>) -> Void) {
        fetchOIDCConfiguration { result in
            switch result {
            case let .success(config):
                guard let authgearOrigin = config.authorizationEndpoint.origin() else {
                    return handler(.failure(wrapError(error: AuthgearError.runtimeError("invalid authorization_endpoint"))))
                }
                let resultURL = authgearOrigin.appendingPathComponent(path)
                return handler(.success(resultURL))
            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOIDCToken(
        grantType: GrantType,
        clientId: String,
        deviceInfo: DeviceInfoRoot? = nil,
        redirectURI: String? = nil,
        code: String? = nil,
        codeVerifier: String? = nil,
        codeChallenge: String? = nil,
        codeChallengeMethod: String? = nil,
        refreshToken: String? = nil,
        jwt: String? = nil,
        accessToken: String? = nil,
        xApp2AppDeviceKeyJwt: String? = nil,
        scope: [String]?,
        requestedTokenType: RequestedTokenType?,
        subjectTokenType: SubjectTokenType?,
        subjectToken: String?,
        actorTokenType: ActorTokenType?,
        actorToken: String?,
        audience: String?,
        deviceSecret: String?,
        handler: @escaping (Result<OIDCTokenResponse, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):

                var queryParams = [String: String]()
                queryParams["client_id"] = clientId
                queryParams["grant_type"] = grantType.rawValue

                if let deviceInfo = deviceInfo {
                    let deviceInfoJSON = try! JSONEncoder().encode(deviceInfo)
                    let xDeviceInfo = deviceInfoJSON.base64urlEncodedString()
                    queryParams["x_device_info"] = xDeviceInfo
                }

                if let code = code {
                    queryParams["code"] = code
                }

                if let redirectURI = redirectURI {
                    queryParams["redirect_uri"] = redirectURI
                }

                if let codeVerifier = codeVerifier {
                    queryParams["code_verifier"] = codeVerifier
                }

                if let codeChallenge = codeChallenge {
                    queryParams["code_challenge"] = codeChallenge
                }

                if let codeChallengeMethod = codeChallengeMethod {
                    queryParams["code_challenge_method"] = codeChallengeMethod
                }

                if let refreshToken = refreshToken {
                    queryParams["refresh_token"] = refreshToken
                }

                if let jwt = jwt {
                    queryParams["jwt"] = jwt
                }

                if let xApp2AppDeviceKeyJwt = xApp2AppDeviceKeyJwt {
                    queryParams["x_app2app_device_key_jwt"] = xApp2AppDeviceKeyJwt
                }
                
                if let scope = scope {
                    queryParams["scope"] = scope.joined(separator: " ")
                }
                
                if let requestedTokenType = requestedTokenType {
                    queryParams["requested_token_type"] = requestedTokenType.rawValue
                }
                
                if let subjectToken = subjectToken {
                    queryParams["subject_token"] = subjectToken
                }
                
                if let subjectTokenType = subjectTokenType {
                    queryParams["subject_token_type"] = subjectTokenType.rawValue
                }
                
                if let actorToken = actorToken {
                    queryParams["actor_token"] = actorToken
                }
                
                if let actorTokenType = actorTokenType {
                    queryParams["actor_token_type"] = actorTokenType.rawValue
                }

                if let audience = audience {
                    queryParams["audience"] = audience
                }
                
                if let deviceSecret = deviceSecret {
                    queryParams["device_secret"] = deviceSecret
                }

                var urlComponents = URLComponents()
                urlComponents.queryParams = queryParams

                let body = urlComponents.query?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.data(using: .utf8)

                var urlRequest = URLRequest(url: config.tokenEndpoint)
                if let accessToken = accessToken {
                    urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
                }
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                self?.fetch(request: urlRequest, handler: handler)

            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestBiometricSetup(
        clientId: String,
        accessToken: String,
        jwt: String,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):
                var queryParams = [String: String]()
                queryParams["client_id"] = clientId
                queryParams["grant_type"] = GrantType.biometric.rawValue
                queryParams["jwt"] = jwt

                var urlComponents = URLComponents()
                urlComponents.queryParams = queryParams

                let body = urlComponents.query?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.data(using: .utf8)

                var urlRequest = URLRequest(url: config.tokenEndpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                authgearFetch(urlSession: self!.defaultSession, request: urlRequest, handler: { result in
                    handler(result.map { _ in () })
                })
            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOIDCUserInfo(
        accessToken: String,
        handler: @escaping (Result<UserInfo, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):
                var urlRequest = URLRequest(url: config.userinfoEndpoint)
                urlRequest.setValue(
                    "Bearer \(accessToken)",
                    forHTTPHeaderField: "authorization"
                )
                self?.fetch(request: urlRequest, keyDecodingStrategy: .useDefaultKeys, handler: handler)

            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOIDCRevocation(
        refreshToken: String,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):

                var urlComponents = URLComponents()
                urlComponents.queryParams = ["token": refreshToken]

                let body = urlComponents.query?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.data(using: .utf8)

                var urlRequest = URLRequest(url: config.revocationEndpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                authgearFetch(urlSession: self!.defaultSession, request: urlRequest, handler: { result in
                    handler(result.map { _ in () })
                })
            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOAuthChallenge(
        purpose: String,
        handler: @escaping (Result<ChallengeResponse, Error>) -> Void
    ) {
        makeAuthgearURL(path: "/oauth2/challenge") { result in
            switch result {
            case let .failure(err):
                handler(.failure(err))
            case let .success(url):
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
                urlRequest.httpBody = try? JSONEncoder().encode(ChallengeBody(purpose: purpose))

                self.fetch(request: urlRequest, handler: { (result: Result<APIResponse<ChallengeResponse>, Error>) in
                    handler(result.flatMap { $0.toResult() })
                })
            }
        }
    }

    func requestAppSessionToken(
        refreshToken: String,
        handler: @escaping (Result<AppSessionTokenResponse, Error>) -> Void
    ) {
        makeAuthgearURL(path: "/oauth2/app_session_token") { result in
            switch result {
            case let .failure(err):
                handler(.failure(err))
            case let .success(url):
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
                urlRequest.httpBody = try? JSONEncoder().encode(AppSessionTokenBody(refreshToken: refreshToken))

                self.fetch(request: urlRequest, handler: { (result: Result<APIResponse<AppSessionTokenResponse>, Error>) in
                    handler(result.flatMap { $0.toResult() })
                })
            }
        }
    }

    func requestWechatAuthCallback(code: String, state: String, handler: @escaping (Result<Void, Error>) -> Void) {
        let queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "x_platform", value: "ios")
        ]
        var urlComponents = URLComponents()
        urlComponents.queryItems = queryItems

        makeAuthgearURL(path: "/sso/wechat/callback") { result in
            switch result {
            case let .failure(err):
                handler(.failure(err))
            case let .success(url):
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = urlComponents.query?.data(using: .utf8)
                authgearFetch(urlSession: self.defaultSession, request: urlRequest, handler: { result in
                    handler(result.map { _ in () })
                })
            }
        }
    }
}
