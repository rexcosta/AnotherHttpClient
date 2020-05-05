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

import XCTest
@testable import AnotherHttpClient

final class AnotherHttpClientTests: XCTestCase {
    
    func testGetCancel() throws {
        let session = URLSession.init(configuration: .ephemeral)
        let network = AnotherHttpClient(session: session)
        
        let request = NetworkRequest(
            timeout: 30,
            url: "https://developer.apple.com/documentation",
            method: .get
        )
        
        let expectation = XCTestExpectation(description: "Download developer.apple.com/documentation page")
        
        network
            .requestData(request: request)
            .handleEvents(receiveCancel: {
                expectation.fulfill()
            })
            .sink(receiveCompletion: { _ in
                XCTFail("[testCancel] Shouldn't receive completion")
            }, receiveValue: { _ in
                XCTFail("[testCancel] Shouldn't receive value")
            })
            .cancel()
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetDataRequest() throws {
        let session = URLSession(configuration: .ephemeral)
        let network = AnotherHttpClient(session: session)
        
        let request = NetworkRequest(
            timeout: 30,
            url: "https://www.apple.com/library/test/success.html",
            method: .get
        )
        
        let expectation = XCTestExpectation(description: "Download apple success page")
        var cancelables = Set<AnyCancellable>()
        network
            .requestData(request: request)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }
                
            }, receiveValue: { result in
                let expected = "<BODY>\nSuccess\n</BODY>"
                guard let htmlPage = String(data: result, encoding: .utf8) else {
                    XCTFail("[testDataRequest] Didn't received the html page")
                    return
                }
                XCTAssertTrue(htmlPage.contains(expected))
            }).store(in: &cancelables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetJsonRequest() {
        let session = URLSession(configuration: .ephemeral)
        let network = AnotherHttpClient(session: session)
        let pageToRequest = 2
        
        let request = NetworkRequest(
            timeout: 30,
            url: "https://reqres.in/api/users",
            parameters: [
                // The API permits a delay param, add some delay
                HttpQueryParameter(name: "delay", value: "\(2)"),
                HttpQueryParameter(name: "page", value: "\(pageToRequest)")
            ],
            method: .get
        )
        
        let expectation = XCTestExpectation(description: "List reqres api users")
        var cancelables = Set<AnyCancellable>()
        network
            .requestJsonObject(request: request)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }
                
            }, receiveValue: { result in
                guard let currentPage = result["page"] as? Int else {
                    XCTFail("[testJsonRequest] Didn't received the page json element")
                    return
                }
                XCTAssertEqual(currentPage, pageToRequest)
            }).store(in: &cancelables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPostDecodableRequest() {
        struct Teste: Decodable {
            let token: String
        }
        
        let body = [
            "email": "eve.holt@reqres.in",
            "password": "cityslicka"
        ]
        let bodyData: Data?
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            XCTFail("[testJsonRequest] Error on JSONSerialization \(error.localizedDescription)")
            return
        }
        
        let session = URLSession(configuration: .ephemeral)
        let network = AnotherHttpClient(session: session)
        
        let request = NetworkRequest(
            timeout: 30,
            url: "https://reqres.in/api/login",
            headers: [
                HttpHeader.contentType(.json)
            ],
            parameters: [
                // The API permits a delay param, add some delay
                HttpQueryParameter(name: "delay", value: "\(2)"),
            ],
            body: bodyData,
            method: .post
        )
        
        let expectation = XCTestExpectation(description: "Login into reqres")
        var cancelables = Set<AnyCancellable>()
        network
            .requestDecodable(request: request)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }
                
            }, receiveValue: { (result: Teste) in
                expectation.fulfill()
            }).store(in: &cancelables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    static var allTests = [
        ("testGetCancel", testGetCancel),
        ("testGetDataRequest", testGetDataRequest),
        ("testGetJsonRequest", testGetJsonRequest),
        ("testPostDecodableRequest", testPostDecodableRequest),
    ]
    
}
