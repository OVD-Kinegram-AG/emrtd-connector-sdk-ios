import SwiftUI
import KinegramEmrtdConnector

// MARK: - StatusView

struct StatusView: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - ResultView

struct ResultView: View {
    let result: ValidationResult

    var body: some View {
        VStack(spacing: 12) {
            Text("Validation Result")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(result.isValid ? .green : .red)

                Text(result.isValid ? "VALID" : "INVALID")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(result.isValid ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Status: \(result.status)", systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Authentication status
                HStack(spacing: 16) {
                    StatusIndicator(label: "CA", status: result.chipAuthResult)
                    StatusIndicator(label: "PA", status: result.passiveAuthResult)
                    StatusIndicator(label: "AA", status: result.activeAuthResult)
                }
                .padding(.vertical, 4)

                if let mrzInfo = result.mrzInfo {
                    Label("Name: \(mrzInfo.primaryIdentifier) \(mrzInfo.secondaryIdentifier)", systemImage: "person")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("Document: \(mrzInfo.documentNumber)", systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal)
    }
}

// MARK: - StatusIndicator

struct StatusIndicator: View {
    let label: String
    let status: String?

    var statusColor: Color {
        guard let status = status?.lowercased() else { return .gray }

        switch status {
        case "valid", "success", "successful", "ok", "succeeded":
            return .green
        case "failed", "fail", "error", "invalid", "failure":
            return .red
        case "unavailable", "not_available", "na", "n/a", "not_performed":
            return .gray
        default:
            return .orange
        }
    }

    var statusSymbol: String {
        guard let status = status?.lowercased() else { return "minus" }

        switch status {
        case "valid", "success", "successful", "ok", "succeeded":
            return "checkmark"
        case "failed", "fail", "error", "invalid", "failure":
            return "xmark"
        case "unavailable", "not_available", "na", "n/a", "not_performed":
            return "minus"
        default:
            return "questionmark"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Image(systemName: "\(statusSymbol).circle.fill")
                .font(.title3)
                .foregroundColor(statusColor)

            // Debug: Show actual status value
            if let status = status {
                Text(status)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
    }
}
