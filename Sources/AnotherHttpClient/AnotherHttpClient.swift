//
// The MIT License (MIT)
//
// Copyright (c) 2020 Effective Like ABoss, David Costa Gonçalves
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import AnotherSwiftCommonLib
import Combine
import Foundation

public final class AnotherHttpClient {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let requestTranformer: RequestTranformer
    
    public init(
        session: URLSession,
        decoder: JSONDecoder = JSONDecoder(),
        requestTranformer: RequestTranformer? = nil
    ) {
        self.session = session
        self.decoder = decoder
        if let requestTranformer = requestTranformer {
            self.requestTranformer = requestTranformer
        } else {
            self.requestTranformer = {
                return $0.transformToRequest()
            }
        }
    }
    
    public convenience init(
        queue: OperationQueue,
        config: URLSessionConfiguration,
        decoder: JSONDecoder = JSONDecoder(),
        requestTranformer: RequestTranformer? = nil
    ) {
        self.init(
            session: URLSession(
                configuration: config,
                delegate: nil,
                delegateQueue: queue
            ),
            decoder: decoder,
            requestTranformer: requestTranformer
        )
    }
    
}

extension AnotherHttpClient: NetworkProtocol {
    
    public func requestData(request: NetworkRequest) -> AnyPublisher<Data, NetworkError> {
        guard let urlRequest = requestTranformer(request) else {
            return Fail(error: NetworkError.unableToBuildRequest(request)).eraseToAnyPublisher()
        }
        
        return session
            .dataTaskPublisher(for: urlRequest)
            .tryMap({ (data: Data, response: URLResponse) -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.unknown(cause: nil)
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    throw NetworkError.invalidStatusCode(code: httpResponse.statusCode)
                }
                return data
            }).mapError({ error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                if let urlerror = error as? URLError {
                    return NetworkError.networkError(cause: urlerror)
                }
                return NetworkError.unknown(cause: error)
            }).eraseToAnyPublisher()
    }
    
    public func requestJsonObject(request: NetworkRequest) -> AnyPublisher<[String: Any], NetworkError> {
        return requestData(request: request)
            .tryMap { try AnotherHttpClient.deserializeJsonData($0) }
            .mapError({ error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.unknown(cause: error)
            })
            .eraseToAnyPublisher()
    }
    
    public func requestJsonArray(request: NetworkRequest) -> AnyPublisher<[Any], NetworkError> {
        return requestData(request: request)
            .tryMap { try AnotherHttpClient.deserializeJsonData($0) }
            .mapError({ error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.unknown(cause: error)
            })
            .eraseToAnyPublisher()
    }
    
    public func requestDecodable<T: Decodable>(request: NetworkRequest) -> AnyPublisher<T, NetworkError> {
        let decoder = self.decoder
        return requestData(request: request)
            .decode(type: T.self, decoder: decoder)
            .mapError({ error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                if let decodeError = error as? DecodingError {
                    return NetworkError.decode(cause: decodeError)
                }
                return NetworkError.unknown(cause: error)
            })
            .eraseToAnyPublisher()
    }
    
}

extension AnotherHttpClient {
    
    private static func deserializeJsonData<T>(_ data: Data) throws -> T {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? T else {
            throw NetworkError.invalidJson
        }
        return json
    }
    
}
