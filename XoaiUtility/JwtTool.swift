//
//  JwtTool.swift
//  XoaiUtility
//
//  JWT decode: colored segments, header / payload / signature panes, claim rows.
//  The signature is NOT verified (client-side decode only).
//

import SwiftUI

// MARK: - Decoding

struct JWTDecoded {
    let headerPretty: String
    let payloadPretty: String
    let payload: [String: Any]
    let sig: String
    let parts: [String]
}

enum JWTResult {
    case empty
    case error(String)
    case ok(JWTDecoded)

    /// Error message for logging, or nil when not an error.
    var errorText: String? { if case let .error(m) = self { return m }; return nil }
}

enum JWTCodec {
    static func base64urlToString(_ seg: String) -> String? {
        var s = seg.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let data = Data(base64Encoded: s) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ raw: String) -> JWTResult {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return .empty }
        let parts = t.components(separatedBy: ".")
        if parts.count != 3 {
            return .error("Token phải có 3 phần ngăn bởi dấu chấm (hiện tại: \(parts.count))")
        }
        guard let h = base64urlToString(parts[0]), let p = base64urlToString(parts[1]),
              let hData = h.data(using: .utf8), let pData = p.data(using: .utf8),
              let headerObj = try? JSONSerialization.jsonObject(with: hData),
              let payloadObj = try? JSONSerialization.jsonObject(with: pData),
              let payloadDict = payloadObj as? [String: Any] else {
            return .error("Không giải mã được header/payload (Base64URL hoặc JSON sai)")
        }
        return .ok(JWTDecoded(
            headerPretty: pretty(headerObj),
            payloadPretty: pretty(payloadObj),
            payload: payloadDict,
            sig: parts[2],
            parts: parts
        ))
    }

    private static func pretty(_ obj: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: obj,
                                                  options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }
}

private func jwtTime(_ value: Any?) -> String? {
    guard let n = value as? NSNumber else { return nil }
    let date = Date(timeIntervalSince1970: n.doubleValue)
    let df = DateFormatter()
    df.locale = Locale(identifier: "vi_VN")
    df.dateFormat = "HH:mm:ss · d/M/yyyy"
    return df.string(from: date)
}

// MARK: - Tool

private let jwtSample = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEyOCIsIm5hbWUiOiJYb2FpIERldiIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTcxNzc2MDAwMCwiZXhwIjoxOTAwMDAwMDAwfQ.s6mB7H6m3Yk0pQ1zT4w8nC2vL9xR0aJdKfElGhIjK0M"

struct JwtTool: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel

    @State private var input = jwtSample
    @State private var editing = false

    private var t: ThemeTokens { theme.t }

    private var decoded: JWTResult { JWTCodec.decode(input) }

    private var expInfo: (exp: Bool, expired: Bool) {
        guard case let .ok(d) = decoded, let exp = d.payload["exp"] as? NSNumber else { return (false, false) }
        return (true, Date().timeIntervalSince1970 > exp.doubleValue)
    }

    var body: some View {
        ToolFrame {
            inputPane
        } output: {
            outputPane
        }
        .onAppear(perform: applySeed)
        .onChange(of: model.seed?.n) { applySeed() }
        .logErrors(.jwt, message: decoded.errorText)
    }

    private func applySeed() {
        if model.active == .jwt, let s = model.seed { input = s.value; editing = false }
    }

    // MARK: Input

    private var inputPane: some View {
        Pane(
            label: "JWT Token",
            grow: true,
            right: AnyView(HStack(spacing: 4) {
                Btn(icon: DKIcon.paste, title: "Dán") { input = Clip.paste(); editing = false }
                Btn(title: "Ví dụ", mono: true) { input = jwtSample; editing = false }
                Btn(icon: DKIcon.clear, title: "Xóa") { input = ""; editing = true }
            }),
            footer: AnyView(HStack {
                CountBar(text: input)
                Spacer()
                if case .ok = decoded { statusChip }
            })
        ) {
            VStack(spacing: 0) {
                colorJwt
                if case let .error(msg) = decoded { Banner(message: msg) }
            }
        }
    }

    private var statusChip: some View {
        let info = expInfo
        let color = info.expired ? t.danger : info.exp ? t.accent : t.textFaint
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(info.expired ? "Đã hết hạn" : info.exp ? "Còn hiệu lực" : "Không có exp")
                .font(DK.mono(11))
        }
        .foregroundStyle(color)
    }

    @ViewBuilder
    private var colorJwt: some View {
        if case let .ok(d) = decoded, !editing {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    (Text(d.parts[0]).foregroundColor(t.hlKey)
                     + Text(".").foregroundColor(t.textFaint)
                     + Text(d.parts[1]).foregroundColor(t.accent)
                     + Text(".").foregroundColor(t.textFaint)
                     + Text(d.parts[2]).foregroundColor(t.danger))
                        .font(DK.mono(13))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Button { editing = true } label: {
                    Text("Sửa token")
                        .font(DK.ui(11))
                        .foregroundStyle(t.textDim)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(t.panel2, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        } else {
            CodeArea(text: $input, placeholder: "Dán JWT token…")
        }
    }

    // MARK: Output

    @ViewBuilder
    private var outputPane: some View {
        switch decoded {
        case .ok(let d):
            ScrollView {
                VStack(spacing: 10) {
                    JwtSection(title: "Header", color: t.hlKey, pretty: d.headerPretty)
                    JwtSection(title: "Payload", color: t.accent, pretty: d.payloadPretty,
                               claims: AnyView(ClaimRows(payload: d.payload, expired: expInfo.expired)))
                    signaturePane(d.sig)
                }
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            Pane(label: "Kết quả giải mã", grow: true) {
                EmptyHint(hint: "Dán JWT để xem header & payload")
            }
        case .error:
            Pane(label: "Kết quả giải mã", grow: true) {
                EmptyHint(hint: "Token không hợp lệ")
            }
        }
    }

    private func signaturePane(_ sig: String) -> some View {
        Pane(label: "Signature") {
            VStack(alignment: .leading, spacing: 10) {
                Text(sig)
                    .font(DK.mono(12.5))
                    .foregroundStyle(t.danger)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    CopyBtn(label: "Chép signature", small: true) { sig }
                    Text("Chữ ký không được xác thực ở phía client")
                        .font(DK.ui(11)).foregroundStyle(t.textFaint)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Sections

private struct JwtSection: View {
    @EnvironmentObject var theme: ThemeManager
    let title: String
    let color: Color
    let pretty: String
    var claims: AnyView? = nil

    private var t: ThemeTokens { theme.t }

    private var prettyHeight: CGFloat {
        CGFloat(pretty.components(separatedBy: "\n").count) * 19 + 24
    }

    var body: some View {
        Pane(
            label: title,
            labelColor: color,
            right: AnyView(CopyBtn(small: true) { pretty })
        ) {
            VStack(spacing: 0) {
                CodeTextView(attributed: jsonAttributed(pretty, t))
                    .frame(height: min(220, prettyHeight))
                if let claims { claims }
            }
        }
    }
}

private struct ClaimRows: View {
    @EnvironmentObject var theme: ThemeManager
    let payload: [String: Any]
    let expired: Bool

    private var t: ThemeTokens { theme.t }

    private var rows: [(label: String, key: String, value: NSNumber)] {
        [("Phát hành (iat)", "iat"), ("Hiệu lực từ (nbf)", "nbf"), ("Hết hạn (exp)", "exp")]
            .compactMap { item in
                (payload[item.1] as? NSNumber).map { (item.0, item.1, $0) }
            }
    }

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(rows, id: \.key) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label).foregroundStyle(t.textDim).frame(width: 130, alignment: .leading)
                        Text(row.value.stringValue).font(DK.mono(12))
                            .foregroundStyle(t.textFaint).frame(width: 96, alignment: .leading)
                        if let time = jwtTime(row.value) {
                            let isExp = row.key == "exp"
                            Text(time + (isExp && expired ? "  · đã hết hạn" : ""))
                                .foregroundStyle(isExp && expired ? t.danger : t.text)
                        }
                        Spacer(minLength: 0)
                    }
                    .font(DK.ui(12))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .top)
        }
    }
}
