import SwiftUI
import KinegramEmrtdConnector

struct ContentView: View {

    // View Model handles all business logic
    // And also the EmrtdConnector instance and shows the usage of it
    @StateObject private var viewModel = ConnectorViewModel()

    @State private var selectedTab = 0
    @AppStorage("lastUsedCAN") private var lastUsedCAN = ""
    @AppStorage("lastUsedDocNumber") private var lastUsedDocNumber = ""
    @AppStorage("lastUsedBirthDate") private var lastUsedBirthDate = ""
    @AppStorage("lastUsedExpiryDate") private var lastUsedExpiryDate = ""

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("OVD KINEGRAM\neMRTD Connector Example")
                .multilineTextAlignment(.center)
                .font(.title)
                .padding(.top, 30)

            // Status display
            StatusView(text: viewModel.statusText)
                .frame(minHeight: 70)

            // Tab selection
            Picker("Access Method", selection: $selectedTab) {
                Text("CAN").tag(0)
                Text("MRZ").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Tab content
            if selectedTab == 0 {
                canInputView
            } else {
                mrzInputView
            }

            // Tip: You can also enable automatic PACE selection in ConnectorViewModel.
            // See the commented example near the validate() call.

            // Action button
            Button(action: {
                Task {
                    if selectedTab == 0 {
                        await viewModel.validateWithCAN()
                    } else {
                        await viewModel.validateWithMRZ()
                    }
                }
            }) {
                Label("Validate Document", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTab == 0 ? viewModel.canButtonDisabled : viewModel.mrzButtonDisabled)
            .padding(.horizontal)

            // Validation result
            if let result = viewModel.validationResult {
                ResultView(result: result)
            }

            Spacer()
        }
        .onAppear {
            // Load last used values on appear
            if !lastUsedCAN.isEmpty {
                viewModel.canNumber = lastUsedCAN
            }
            if !lastUsedDocNumber.isEmpty {
                viewModel.documentNumber = lastUsedDocNumber
            }
            if !lastUsedBirthDate.isEmpty {
                viewModel.birthDate = lastUsedBirthDate
            }
            if !lastUsedExpiryDate.isEmpty {
                viewModel.expiryDate = lastUsedExpiryDate
            }
        }
    }

    // MARK: - CAN Input View

    var canInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Access Number (CAN)")
                .font(.headline)

            TextField("Enter 6-digit CAN", text: $viewModel.canNumber)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .onChange(of: viewModel.canNumber) { newValue in
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        viewModel.canNumber = String(newValue.prefix(6))
                    }
                    // Save to AppStorage
                    if newValue.count == 6 {
                        lastUsedCAN = newValue
                    }
                }

            Text("The CAN is typically printed on the document")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - MRZ Input View

    var mrzInputView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Number")
                    .font(.headline)

                TextField("e.g. P1234567", text: $viewModel.documentNumber)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: viewModel.documentNumber) { newValue in
                        // Remove spaces and limit length
                        viewModel.documentNumber = String(newValue.replacingOccurrences(of: " ", with: "").prefix(9))
                        if !newValue.isEmpty {
                            lastUsedDocNumber = viewModel.documentNumber
                        }
                    }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Birth Date")
                        .font(.headline)

                    TextField("YYMMDD", text: $viewModel.birthDate)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.birthDate) { newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                viewModel.birthDate = String(newValue.prefix(6))
                            }
                            if newValue.count == 6 {
                                lastUsedBirthDate = newValue
                            }
                        }

                    Text("e.g. 900515")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Expiry Date")
                        .font(.headline)

                    TextField("YYMMDD", text: $viewModel.expiryDate)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.expiryDate) { newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                viewModel.expiryDate = String(newValue.prefix(6))
                            }
                            if newValue.count == 6 {
                                lastUsedExpiryDate = newValue
                            }
                        }

                    Text("e.g. 251231")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

}

#Preview {
    ContentView()
}
