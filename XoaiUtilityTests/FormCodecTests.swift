//
//  FormCodecTests.swift
//  XoaiUtilityTests
//

import Testing
import Foundation
@testable import XoaiUtility

struct FormCodecTests {

    @Test func parsesRealFormPayload() {
        let body = "feature_ids=%5b%22feature_drip_7d%22%2c%22feature_drip_14d%22%2c%22feature_drip_30d%22%5d&ab_attributes=%7b%22platform%22%3a%22OSXEditor%22%2c%22client_version%22%3a%221.0.0%22%7d&unique_nonce=b6d3dfad-9736-4722-b19f-5f5409a6cd0e&ts=1775036682&signature=sXEL73a3BTaW1FU8_Ozyud1WcDRiwXW4zfWAiCjdvqU%3d"
        let pairs = FormCodec.pairs(body)
        #expect(pairs.count == 5)
        #expect(pairs[0].key == "feature_ids")
        #expect(pairs[0].value == "[\"feature_drip_7d\",\"feature_drip_14d\",\"feature_drip_30d\"]")
        #expect(pairs[1].key == "ab_attributes")
        #expect(pairs[1].value == "{\"platform\":\"OSXEditor\",\"client_version\":\"1.0.0\"}")
        #expect(pairs[2].value == "b6d3dfad-9736-4722-b19f-5f5409a6cd0e")
        #expect(pairs[3].value == "1775036682")
        #expect(pairs[4].key == "signature")
        #expect(pairs[4].value == "sXEL73a3BTaW1FU8_Ozyud1WcDRiwXW4zfWAiCjdvqU=")
    }

    @Test func decodesPlusAsSpace() {
        let pairs = FormCodec.pairs("greeting=hello+world&name=a+b")
        #expect(pairs[0].value == "hello world")
        #expect(pairs[1].value == "a b")
    }

    @Test func segmentWithoutEqualsHasEmptyValue() {
        let pairs = FormCodec.pairs("flag&x=1")
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "flag")
        #expect(pairs[0].value == "")
        #expect(pairs[1].key == "x")
        #expect(pairs[1].value == "1")
    }

    @Test func emptyInputIsEmpty() {
        #expect(FormCodec.pairs("").isEmpty)
        #expect(FormCodec.pairs("   ").isEmpty)
    }

    @Test func fullUrlParsesQueryAndDropsFragment() {
        let pairs = FormCodec.pairs("https://api.dev.io/search?a=1&b=2#frag")
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "a")
        #expect(pairs[0].value == "1")
        #expect(pairs[1].key == "b")
        #expect(pairs[1].value == "2")
    }

    @Test func encodedEqualsInValueIsPreserved() {
        let pairs = FormCodec.pairs("token=ab%3dcd")
        #expect(pairs.count == 1)
        #expect(pairs[0].value == "ab=cd")
    }

    @Test func idsAreSequential() {
        let pairs = FormCodec.pairs("a=1&b=2&c=3")
        #expect(pairs.map(\.id) == [0, 1, 2])
    }
}
